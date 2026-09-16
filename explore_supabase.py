import requests

SUPABASE_URL = "https://jzolrefuiagifgpnfqnj.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6b2xyZWZ1aWFnaWZncG5mcW5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNzE0MjksImV4cCI6MjEwMzg0NzQyOX0.LiHD8IeE2fKnqk5NWyqNY10amTJAefJYohyo85x-yIU"

def get_tables():
    # This endpoint is sometimes available depending on API settings
    # Alternatively, we can try to hit the /rest/v1/ endpoint to see the error response
    # which often hints at table availability, or use the PostgREST API.
    url = f"{SUPABASE_URL}/rest/v1/"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }
    
    response = requests.get(url, headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")

if __name__ == "__main__":
    get_tables()
