from pydantic import BaseModel

class Product(BaseModel):
    name: str
    category: str
    quantity: int
    price: float
    expiry_date: str

class Expense(BaseModel):
    product_name: str
    quantity: int
    total_cost: float
    date: str
