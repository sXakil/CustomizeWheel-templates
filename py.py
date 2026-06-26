import json

with open("templates_source/Money_Prize/data.json", "r") as f:
    data = json.load(f)

results = data.get("results", [])

i = 0
for result in results:
    result["text"]["text"] = result["text"]["text"].replace("\n", "")

with open("templates_source/Money_Prize/data.json", "w") as f:
    json.dump(data, f, indent=4)