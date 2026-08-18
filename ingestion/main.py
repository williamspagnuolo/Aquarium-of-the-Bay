import os
import requests
from google.cloud import bigquery
from datetime import datetime, timedelta
import pytz

# Initialize BigQuery client (Cloud Run provides auth automatically)
client = bigquery.Client()

dataset_name = "rocket_rez_data"
table_name = "raw_data"
table_id = f"{dataset_name}.{table_name}"


client.query("""
TRUNCATE TABLE `rocket_rez_data.raw_data`
""").result()


# --- AUTH TOKEN ---
token_url = "TOKEN_URL"

token_response = requests.post(
    token_url,
    headers={
        "Accept": "application/json",
        "Content-Type": "application/json"
    },
    json={
        "client_id": os.environ["ROCKET_REZ_CLIENT_ID"],
        "client_secret": os.environ["ROCKET_REZ_CLIENT_SECRET"],
        "scope": "read_orders",
        "grant_type": "client_credentials"
    },
    timeout=30
)


if token_response.status_code != 200:
    raise RuntimeError(
        f"Token request failed ({token_response.status_code}): {token_response.text}"
    )


token = token_response.json()["data"]["access_token"]

# --- API SETUP ---
orders_url = "ORDERS_URL"
orders_headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {token}"
}


# setting the company timezone used by Rocket Rez
# allows us to pull only the data for the day prior to this script being ran (i.e. 4/20 if this script ran 4/21)
COMPANY_TZ = pytz.timezone("America/Los_Angeles")

today = datetime.now(COMPANY_TZ).date()
yesterday = today - timedelta(days=1)

start_date = yesterday.strftime("%Y-%m-%d")
end_date = yesterday.strftime("%Y-%m-%d")

print(f"Fetching Rocket Rez orders for {start_date}")


page_index = 0

while True:
    params = {
        "startDate": start_date,
        "endDate": end_date,
        "pageIndex": page_index
    }

    response = requests.get(
        orders_url, 
        headers=orders_headers, 
        params=params,
        timeout=30
    )

    if response.status_code != 200:
        raise RuntimeError(response.text)

    items = response.json().get("data", [])

    if not items:
        break

    # insert directly into BigQuery
    errors = client.insert_rows_json(
        table_id,
        items,
        ignore_unknown_values=True
    )

    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")

    print(f"Inserted page {page_index} ({len(items)} rows)")

    page_index += 1