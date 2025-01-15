from abc import ABC, abstractmethod

from models import Model


class Pipeline(ABC):

    def __init__(self):
        pass

    @abstractmethod
    def start(self, model: Model, prompt: str) -> object:
        pass
