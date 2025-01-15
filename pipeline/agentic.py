from models import Model
from models.bedrock import Bedrock

from pipeline import Pipeline
from tools.movie_sentence import movie_quote
from tools.travel_advice import travel_advice
from tools.valid_city import valid_city

from langchain.agents import AgentExecutor, create_structured_chat_agent
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts.chat import ChatPromptTemplate, MessagesPlaceholder

from utils import format_message


class Agentic(Pipeline):

    tools = [valid_city, travel_advice, movie_quote]

    __system = """Respond to the human as helpfully and accurately as possible. You have access to the following tools:

{tools}

Use a json blob to specify a tool by providing an action key (tool name) and an action_input key (tool input).

Valid "action" values: "Final Answer" or {tool_names}

Provide only ONE action per $JSON_BLOB, as shown:

```
{{
  "action": $TOOL_NAME,
  "action_input": $INPUT
}}
```

Follow this format:

Question: input question to answer
Thought: consider previous and subsequent steps
Action:
```
$JSON_BLOB
```
Observation: action result
... (repeat Thought/Action/Observation N times)
Thought: I know what to respond
Action:
```
{{
  "action": "Final Answer",
  "action_input": "Final response to human"
}}

Begin! Reminder to ALWAYS respond with a valid json blob of a single action. Use tools if necessary. Respond directly if appropriate. Format is Action:```$JSON_BLOB```then Observation"""

    __human = """

{input}

{agent_scratchpad}

(reminder to respond in a JSON blob no matter what)"""

    def __init__(self):
        super().__init__()
        prompt = ChatPromptTemplate.from_messages(
            [
                ("system", self.__system),
                MessagesPlaceholder("chat_history", optional=True),
                ("human", self.__human),
            ]
        )

        llm = Bedrock().langchain_llm()  # .bind_tools(self.tools)

        agent = create_structured_chat_agent(llm, self.tools, prompt)

        # self.memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)

        self.agent_executor = AgentExecutor(
            agent=agent,
            tools=self.tools,
            verbose=True,
            handle_parsing_errors=True,
            # memory=self.memory,
            max_iterations=10,
        )

    def start(self, model: Model, prompt: str) -> object:
        task = f"if {prompt} is a valid city, provide a travel advice. Otherwise, provide an explanation on why you cannot answer."
        # chat_history = self.memory.buffer_as_messages
        response = self.agent_executor.invoke(
            {
                "input": task,
                # "chat_history": chat_history,
            }
        )
        r = response["output"]
        print("Agent:", r)
        return format_message(r)
