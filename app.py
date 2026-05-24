from typing import Any, Dict

from flask import Flask, jsonify, request


app = Flask(__name__)

SERVER_PORT = 5000
VALID_DEMAND_LEVELS = {"high", "medium", "low"}
VALID_SEASONS = {"all season", "summer", "rainy", "winter", "festival"}
BASE_CATEGORY_PRICE = {
    "vegetables": 30.0,
    "fruits": 46.0,
}


def normalize_text(value: Any) -> str:
    return str(value).strip()


def parse_positive_number(field_name: str, value: Any) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"{field_name} must be a valid number")

    if parsed < 0:
        raise ValueError(f"{field_name} must be 0 or more")

    return parsed


def parse_festival_flag(value: Any) -> int:
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (int, float)):
        return 1 if int(value) != 0 else 0

    normalized = normalize_text(value).lower()
    if normalized in {"1", "true", "yes", "festival"}:
        return 1
    if normalized in {"0", "false", "no", ""}:
        return 0
    raise ValueError("festival_flag must be Yes or No")


def validate_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    required_fields = [
        "item_name",
        "category",
        "season",
        "demand_level",
        "rainfall",
        "temperature",
        "festival_flag",
    ]
    missing_fields = [field for field in required_fields if field not in payload]
    if missing_fields:
        raise ValueError("Missing fields: " + ", ".join(missing_fields))

    item_name = normalize_text(payload.get("item_name"))
    category = normalize_text(payload.get("category")).lower()
    season = normalize_text(payload.get("season")).lower()
    demand_level = normalize_text(payload.get("demand_level")).lower()
    rainfall = parse_positive_number("rainfall", payload.get("rainfall"))
    temperature = parse_positive_number("temperature", payload.get("temperature"))
    festival_flag = parse_festival_flag(payload.get("festival_flag"))

    if not item_name:
        raise ValueError("item_name is required")
    if category not in BASE_CATEGORY_PRICE:
        raise ValueError("category must be Fruits or Vegetables")
    if season not in VALID_SEASONS:
        raise ValueError("season must be All Season, Summer, Rainy, Winter, or Festival")
    if demand_level not in VALID_DEMAND_LEVELS:
        raise ValueError("demand_level must be High, Medium, or Low")

    return {
        "item_name": item_name,
        "category": category,
        "season": season,
        "demand_level": demand_level,
        "rainfall": rainfall,
        "temperature": temperature,
        "festival_flag": festival_flag,
    }


def calculate_predicted_price(
    item_name: str,
    category: str,
    season: str,
    demand_level: str,
    rainfall: float,
    temperature: float,
    festival_flag: int,
) -> float:
    item_key = item_name.strip().lower()
    predicted_price = BASE_CATEGORY_PRICE.get(category, 32.0)

    if "juice" in item_key:
        predicted_price += 12
    if item_key in {"broccoli", "dragon fruit", "kiwi", "strawberry"}:
        predicted_price += 8
    if item_key in {"mint", "coriander", "curry leaves", "spinach"}:
        predicted_price -= 6

    if season == "summer":
        predicted_price += 3
    elif season == "rainy":
        predicted_price += 4
    elif season == "winter":
        predicted_price += 2
    elif season == "festival":
        predicted_price += 6
    else:
        predicted_price += 1

    if demand_level == "high":
        predicted_price += 8
    elif demand_level == "medium":
        predicted_price += 4
    else:
        predicted_price += 1

    if rainfall >= 70:
        predicted_price += 6
    elif rainfall >= 40:
        predicted_price += 4
    elif rainfall >= 15:
        predicted_price += 2

    if temperature >= 35:
        predicted_price += 5
    elif temperature >= 30:
        predicted_price += 3
    elif temperature <= 18:
        predicted_price += 2

    if festival_flag == 1:
        predicted_price += 7

    if item_key == "tomato" and rainfall >= 30:
        predicted_price += 2
    if item_key == "onion" and rainfall >= 50:
        predicted_price += 2
    if item_key == "potato" and temperature >= 32:
        predicted_price += 2

    return round(max(8.0, predicted_price), 2)


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "success",
            "server": "running",
            "port": SERVER_PORT,
            "prediction_mode": "admin_market_buying_price",
        }
    )


@app.post("/predict")
def predict():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"status": "error", "message": "Request body must be valid JSON"}), 400

    try:
        validated = validate_payload(payload)
        predicted_price = calculate_predicted_price(
            item_name=validated["item_name"],
            category=validated["category"],
            season=validated["season"],
            demand_level=validated["demand_level"],
            rainfall=validated["rainfall"],
            temperature=validated["temperature"],
            festival_flag=validated["festival_flag"],
        )
    except ValueError as exc:
        return jsonify({"status": "error", "message": str(exc)}), 400
    except RuntimeError as exc:
        return jsonify({"status": "error", "message": str(exc)}), 500
    except Exception as exc:  # pragma: no cover
        return jsonify({"status": "error", "message": f"Unexpected server error: {exc}"}), 500

    return jsonify(
        {
            "status": "success",
            "item_name": validated["item_name"],
            "predicted_price": predicted_price,
            "temperature": validated["temperature"],
            "humidity": 0.0,
            "rainfall": validated["rainfall"],
        }
    )


if __name__ == "__main__":
    print(f"Gruno Flask API running on port {SERVER_PORT}")
    app.run(host="0.0.0.0", port=SERVER_PORT, debug=False)
