## Test endpoints (Hoàn thành 13:53 11/08/2026)
```bash
# Get all products
curl -i http://localhost:5000/products

# Create a new product
curl -X POST http://localhost:5000/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop"}'
```