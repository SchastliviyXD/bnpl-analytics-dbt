"""Generate synthetic UK BNPL seed data.

Shapes mirror a real instalment book (customers, merchants, plans, payment
schedules) but every value is randomly generated from a fixed seed. No
production data from any company is involved.

Money is stored in PENCE, as a real payment system would — integer minor units
avoid floating-point rounding. Conversion to pounds happens in staging.
"""
import csv, random
from datetime import date, timedelta

random.seed(42)
START = date(2025, 1, 1)
TODAY = date(2026, 8, 1)          # fixed "as of" date so the repo is reproducible

CITIES = ["London", "Manchester", "Birmingham", "Leeds", "Glasgow",
          "Bristol", "Liverpool", "Edinburgh", "Sheffield", "Cardiff"]
CATEGORIES = ["Fashion", "Electronics", "Home & Garden", "Beauty", "Sports"]


def write(name, header, rows):
    with open(f"seeds/{name}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"seeds/{name}.csv  {len(rows)} rows")


merchants = [
    (i, f"Merchant {i:03d}", random.choice(CATEGORIES), random.choice(CITIES))
    for i in range(1, 41)
]
write("raw_merchants", ["merchant_id", "merchant_name", "category", "city"], merchants)

customers = [
    (i, f"Customer {i:05d}", f"+4477{i:08d}", random.choice(CITIES),
     START + timedelta(days=random.randint(0, 400)),
     random.choice(["active", "active", "active", "blocked"]))
    for i in range(1, 2001)
]
write("raw_customers",
      ["customer_id", "full_name", "phone", "city", "registered_at", "status"],
      customers)

plans, installments = [], []
inst_id = 1
for plan_id in range(1, 5001):
    created = START + timedelta(days=random.randint(0, 430))

    # Typical UK BNPL basket: £80-£1,200, held in pence.
    basket_pence = random.choice([8000, 15000, 25000, 40000, 65000, 90000, 120000])
    term = random.choice([3, 3, 4, 6, 12])            # pay-in-3/4 dominate

    # Pay-in-3/4 takes nothing upfront; longer instalment credit often
    # carries a deposit. So payment_number = 1 is a real instalment on short
    # plans but a deposit on long ones.
    deposit_pence = 0 if term <= 4 else round(basket_pence * random.choice([0.1, 0.2]))

    plans.append((plan_id, random.randint(1, 2000), random.randint(1, 40),
                  basket_pence, deposit_pence, term, created))

    # A minority of plans go bad, and badness persists across the schedule —
    # so roll rate and vintage curves have real signal to find.
    bad = random.random() < 0.12
    principal_pence = basket_pence - deposit_pence
    amount_pence = round(principal_pence / term)
    allocated = 0
    for n in range(1, term + 1):
        # The final instalment absorbs the rounding remainder, so the schedule
        # sums exactly to the principal. This is what real lenders do.
        this_amount = amount_pence if n < term else principal_pence - allocated
        allocated += this_amount
        
        due = created + timedelta(days=30 * n)
        if due > TODAY:
            paid = ""                                  # not yet due
        elif bad and random.random() < 0.55:
            paid = ""                                  # missed
        else:
            paid = due + timedelta(days=random.randint(-3, 12))
        installments.append((inst_id, plan_id, n, due, this_amount, paid))
        inst_id += 1

write("raw_plans",
      ["plan_id", "customer_id", "merchant_id", "basket_amount_pence",
       "deposit_amount_pence", "term_months", "created_at"], plans)
write("raw_installments",
      ["installment_id", "plan_id", "payment_number", "due_date",
       "amount_pence", "paid_date"], installments)
