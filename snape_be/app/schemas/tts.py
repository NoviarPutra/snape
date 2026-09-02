from pydantic import BaseModel, Field


class TTSSynthesizeRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Text content to synthesize into speech audio")
