from pydantic import BaseModel, ConfigDict, Field


class MaterialResponse(BaseModel):
    model_config = ConfigDict(from_attributes=False)

    content: str = Field(..., description="Markdown content of the learning material")
    space_slug: str = Field(..., description="Space slug identifier")
    category: str = Field(..., description="Material category")
