import os
from models import Model
from pipeline import Pipeline

from langchain_core.prompts import ChatPromptTemplate, PromptTemplate
from langchain_community.document_loaders import BSHTMLLoader
from langchain_community.vectorstores import FAISS
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser

from utils import format_message


class LangChain(Pipeline):

    def __init__(self):
        super().__init__()
        # Retrieve the source data
        docs_list = []
        for item in os.listdir(path="destinations"):
            if item.endswith(".html"):
                item_docs_list = BSHTMLLoader(file_path=f"destinations/{item}").load()
                for item in item_docs_list:
                    docs_list.append(item)

        # Split Document into tokens
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, chunk_overlap=200
        )
        self._documents = text_splitter.split_documents(docs_list)
        self._prompt = ChatPromptTemplate.from_template(
            """
    1. Use the following pieces of context to answer the question as travel advise at the end.
    2. Keep the answer crisp and limited to 3,4 sentences.

    Context: {context}

    Question: {input}
    
    Helpful Answer:"""
        )

        self._document_prompt = PromptTemplate(
            input_variables=["page_content", "source"],
            template="content:{page_content}\nsource:{source}",
        )

    @staticmethod
    def format_docs(docs):
        return "\n\n".join(doc.page_content for doc in docs)

    def start(self, model: Model, prompt: str):
        vector = FAISS.from_documents(self._documents, model.langchain_embedding())
        retriever = vector.as_retriever()

        rag_chain = (
            {"context": retriever | self.format_docs, "input": RunnablePassthrough()}
            | self._prompt
            | model.langchain_llm()
            | StrOutputParser()
        )
        response = rag_chain.invoke(prompt)
        return format_message(response)
