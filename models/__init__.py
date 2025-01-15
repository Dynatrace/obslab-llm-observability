from abc import ABC, abstractmethod


class Model(ABC):

    def __init__(self):
        pass

    @abstractmethod
    def embedding(self, prompt):
        pass

    @abstractmethod
    def chat(self, prompt):
        pass

    @abstractmethod
    def langchain_embedding(self):
        pass

    @abstractmethod
    def langchain_llm(self):
        pass
