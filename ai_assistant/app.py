import streamlit as st

from bigquery_client import estimate_query, run_query
from gemini_client import generate_sql
from sql_validator import validate_sql


st.set_page_config(
    page_title="Aquarium Analytics Assistant",
    page_icon="🐠",
    layout="wide",
)

st.title("Aquarium Analytics Assistant")
st.write("Ask a question about the approved Aquarium reporting data.")

question = st.text_input(
    "Question",
    placeholder="How many visitors came during the last seven days?",
)

if st.button("Generate answer", type="primary") and question:
    try:
        with st.spinner("Generating and validating SQL..."):
            sql = generate_sql(question)
            validate_sql(sql)
            estimated_bytes = estimate_query(sql)

        st.subheader("Generated SQL")
        st.code(sql, language="sql")

        st.caption(
            f"Estimated data processed: "
            f"{estimated_bytes / 1_000_000:.2f} MB"
        )

        with st.spinner("Running BigQuery query..."):
            results = run_query(sql)

        st.subheader("Results")
        st.dataframe(results, use_container_width=True)

    except Exception as exc:
        st.error(f"The question could not be completed: {exc}")