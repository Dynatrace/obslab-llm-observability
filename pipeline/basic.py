from models import Model
from pipeline import Pipeline
from utils import format_message
from opentelemetry.trace import get_tracer, SpanKind


class Basic(Pipeline):

    def __init__(self):
        super().__init__()
        self.tracer = get_tracer("basic_usage")

    def start(self, model: Model, prompt: str):
        prompt = f"Give travel advise in a paragraph of max 50 words about {prompt}"
        answer = model.chat(prompt)
        return format_message(answer)
