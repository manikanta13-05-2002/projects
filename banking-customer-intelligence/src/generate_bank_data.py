import os
from faker import Faker
import pandas as pd
import random

# Initialize Faker and seed for reproducibility
Faker.seed(42)
random.seed(42)
fake = Faker()

def generate_bank_dataset(num_records=5000):
    bank_data = []
    
    # Account type choices
    account_types = ['Checking', 'Savings', 'Money Market', 'Certificate of Deposit']
    employment_statuses = ['Employed', 'Self-Employed', 'Unemployed', 'Retired', 'Student']
    
    for i in range(num_records):
        # 1. Create a clean, sequential Surrogate Key (1, 2, 3...)
        customer_id = i + 1
        
        # Base Demographics
        first_name = fake.first_name()
        last_name = fake.last_name()
        
        # Derived Financial Metrics
        credit_score = random.randint(300, 850)
        if credit_score < 580: credit_tier = 'Poor'
        elif credit_score < 670: credit_tier = 'Fair'
        elif credit_score < 740: credit_tier = 'Good'
        elif credit_score < 800: credit_tier = 'Very Good'
        else: credit_tier = 'Exceptional'
        
        # Build the updated 19 attributes per customer record
        record = {
            # --- Keys & Core Identifiers (3 attributes) ---
            "Customer_ID": customer_id,                   # Surrogate Key
            "Account_Number": fake.unique.bban(),          # Natural/Business Key
            "Customer_Name": f"{first_name} {last_name}",
            
            # --- Personal & Demographics (4 attributes) ---
            "Email": f"{first_name.lower()}.{last_name.lower()}@{fake.free_email_domain()}",
            "Phone": fake.phone_number(),
            "Age": random.randint(18, 85),
            "Employment_Status": random.choice(employment_statuses),
            
            # --- Account & Financial Details (7 attributes) ---
            "Account_Type": random.choice(account_types),
            "Current_Balance": round(random.uniform(-100, 150000), 2),
            "Credit_Score": credit_score,
            "Credit_Tier": credit_tier,
            "Annual_Income": random.randint(25000, 220000) if credit_score > 500 else random.randint(15000, 60000),
            "Has_Active_Loan": random.choice([True, False]),
            "Mortgage_Balance": random.choice([0, 0, 0, random.randint(50000, 450000)]),
            
            # --- Digital & Behavior Metrics (5 attributes) ---
            "Overdraft_Protection": random.choice([True, False]),
            "Is_Online_Banking_Active": random.choice([True, False]),
            "Last_Transaction_Amount": round(random.uniform(5.00, 1200.00), 2),
            "Risk_Score": round(random.uniform(0.0, 1.0), 2),
            "Account_Created_Date": fake.date_between(start_date='-4y', end_date='today').isoformat() # Adjusted to 4 years for tighter cohorts
        }
        bank_data.append(record)
        
    return pd.DataFrame(bank_data)

if __name__ == "__main__":
    print("Generating 5,000 fake bank records with surrogate keys...")
    df = generate_bank_dataset(num_records=5000)
    
    # Ensure the data directory exists
    os.makedirs('data', exist_ok=True)
    
    # Save to the data folder
    output_path = 'data/fake_bank_customers.csv'
    df.to_csv(output_path, index=False)
    
    print(f"Success! 5,000 records saved to: {output_path}")
    print("\nSample Data Preview (First 3 rows):")
    print(df[['Customer_ID', 'Account_Number', 'Customer_Name', 'Account_Created_Date']].head(3).to_string())