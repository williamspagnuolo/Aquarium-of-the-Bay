import os

from google import genai
from google.genai import types

from schema_context import SCHEMA_CONTEXT


PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "rocket-rez-api")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")


client = genai.Client(
    vertexai=True,
    project=PROJECT_ID,
    location=LOCATION,
)


def generate_sql(question: str) -> str:
    """Convert a business question into one BigQuery SELECT statement."""

    prompt = f"""
{SCHEMA_CONTEXT}

User question:
{question}

Return only the SQL query. Do not use Markdown fences or provide an explanation.
"""

    response = client.models.generate_content(
        model=MODEL_NAME,
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0,
            max_output_tokens=1000,
        ),
    )

    if not response.text:
        raise ValueError("Gemini did not return a SQL query.")

    return (
        response.text
        .replace("```sql", "")
        .replace("```", "")
        .strip()
    )