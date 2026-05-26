from __future__ import annotations

from pathlib import Path
from random import Random
from typing import Any

import numpy as np
import pandas as pd
from faker import Faker


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "data" / "generated"

SEED = 42
N_ACCOUNTS = 250
START_DATE = pd.Timestamp("2024-01-01")
END_DATE = pd.Timestamp("2025-12-31")


def random_date(rng: Random, start: pd.Timestamp, end: pd.Timestamp) -> pd.Timestamp:
    if end < start:
        raise ValueError(f"Invalid date range: start={start}, end={end}")

    days = (end - start).days
    return start + pd.Timedelta(days=rng.randint(0, days))


def weighted_choice(rng: Random, values: list[str], weights: list[float]) -> str:
    return rng.choices(values, weights=weights, k=1)[0]


def write_csv(df: pd.DataFrame, filename: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUTPUT_DIR / filename
    df.to_csv(path, index=False)
    print(f"Created {path.relative_to(PROJECT_ROOT)} ({len(df):,} rows)")


def build_accounts(fake: Faker, rng: Random) -> pd.DataFrame:
    industries = [
        "FinTech",
        "HealthTech",
        "E-commerce",
        "Education",
        "Logistics",
        "Manufacturing",
        "Professional Services",
        "SaaS",
    ]
    segments = ["SMB", "Mid-Market", "Enterprise"]
    segment_weights = [0.55, 0.32, 0.13]
    countries = ["Mexico", "United States", "Canada", "Colombia", "Chile", "Spain"]

    rows: list[dict[str, Any]] = []

    for i in range(1, N_ACCOUNTS + 1):
        segment = weighted_choice(rng, segments, segment_weights)
        employee_band = {
            "SMB": weighted_choice(rng, ["1-10", "11-50", "51-100"], [0.25, 0.55, 0.20]),
            "Mid-Market": weighted_choice(rng, ["101-250", "251-500", "501-1000"], [0.40, 0.40, 0.20]),
            "Enterprise": weighted_choice(rng, ["1001-5000", "5001+"], [0.70, 0.30]),
        }[segment]

        created_at = random_date(rng, START_DATE, pd.Timestamp("2025-09-30"))

        rows.append(
            {
                "account_id": f"acc_{i:04d}",
                "account_name": fake.company(),
                "industry": weighted_choice(rng, industries, [0.16, 0.12, 0.16, 0.10, 0.11, 0.10, 0.12, 0.13]),
                "segment": segment,
                "employee_band": employee_band,
                "country": weighted_choice(rng, countries, [0.38, 0.25, 0.10, 0.10, 0.07, 0.10]),
                "created_at": created_at.date().isoformat(),
                "account_owner": fake.name(),
            }
        )

    return pd.DataFrame(rows)


def build_contacts(accounts: pd.DataFrame, fake: Faker, rng: Random) -> pd.DataFrame:
    roles = ["Admin", "Executive Sponsor", "Finance", "Operations", "Analyst", "Technical Owner"]
    rows: list[dict[str, Any]] = []
    contact_id = 1

    for account in accounts.itertuples(index=False):
        if account.segment == "Enterprise":
            n_contacts = rng.randint(4, 8)
        elif account.segment == "Mid-Market":
            n_contacts = rng.randint(2, 5)
        else:
            n_contacts = rng.randint(1, 3)

        for _ in range(n_contacts):
            rows.append(
                {
                    "contact_id": f"con_{contact_id:05d}",
                    "account_id": account.account_id,
                    "email": fake.unique.email(),
                    "full_name": fake.name(),
                    "role": weighted_choice(rng, roles, [0.25, 0.12, 0.14, 0.20, 0.18, 0.11]),
                    "created_at": account.created_at,
                }
            )
            contact_id += 1

    return pd.DataFrame(rows)


def build_deals(accounts: pd.DataFrame, rng: Random) -> pd.DataFrame:
    stages = ["prospecting", "qualified", "proposal", "negotiation", "closed_won", "closed_lost"]
    plans = ["Starter", "Growth", "Scale", "Enterprise"]
    rows: list[dict[str, Any]] = []

    for i, account in enumerate(accounts.itertuples(index=False), start=1):
        segment = account.segment

        base_amount = {
            "SMB": rng.randint(3_000, 18_000),
            "Mid-Market": rng.randint(18_000, 75_000),
            "Enterprise": rng.randint(75_000, 250_000),
        }[segment]

        created_at = pd.Timestamp(account.created_at) + pd.Timedelta(days=rng.randint(0, 90))
        stage = weighted_choice(rng, stages, [0.10, 0.12, 0.12, 0.10, 0.46, 0.10])

        close_date = None
        if stage in {"closed_won", "closed_lost"}:
            close_date = created_at + pd.Timedelta(days=rng.randint(15, 120))

        rows.append(
            {
                "deal_id": f"deal_{i:05d}",
                "account_id": account.account_id,
                "deal_name": f"{account.account_name} - New Business",
                "pipeline": "new_business",
                "deal_stage": stage,
                "deal_amount_usd": base_amount,
                "expected_mrr_usd": round(base_amount / 12, 2),
                "plan": weighted_choice(rng, plans, [0.35, 0.35, 0.20, 0.10]),
                "created_at": created_at.date().isoformat(),
                "close_date": close_date.date().isoformat() if close_date is not None else "",
            }
        )

    return pd.DataFrame(rows)


def build_billing(accounts: pd.DataFrame, deals: pd.DataFrame, rng: Random) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    won_deals = deals[deals["deal_stage"] == "closed_won"].copy()

    customers: list[dict[str, Any]] = []
    subscriptions: list[dict[str, Any]] = []
    invoices: list[dict[str, Any]] = []
    payments: list[dict[str, Any]] = []

    subscription_id = 1
    invoice_id = 1
    payment_id = 1

    for deal in won_deals.itertuples(index=False):
        account = accounts.loc[accounts["account_id"] == deal.account_id].iloc[0]

        customer_id = f"cus_{subscription_id:05d}"
        sub_id = f"sub_{subscription_id:05d}"

        start_date = pd.Timestamp(deal.close_date) + pd.Timedelta(days=rng.randint(0, 10))

        if start_date > END_DATE:
            continue

        status = weighted_choice(rng, ["active", "past_due", "canceled"], [0.76, 0.12, 0.12])

        cancel_date = ""
        if status == "canceled":
            cancel_candidate = start_date + pd.Timedelta(days=rng.randint(90, 450))
            if cancel_candidate < END_DATE:
                cancel_date = cancel_candidate.date().isoformat()
            else:
                status = "active"

        billing_cycle = weighted_choice(rng, ["monthly", "annual"], [0.72, 0.28])
        mrr = float(deal.expected_mrr_usd)

        customers.append(
            {
                "billing_customer_id": customer_id,
                "account_id": deal.account_id,
                "customer_name": account["account_name"],
                "created_at": start_date.date().isoformat(),
                "country": account["country"],
            }
        )

        subscriptions.append(
            {
                "subscription_id": sub_id,
                "billing_customer_id": customer_id,
                "account_id": deal.account_id,
                "plan": deal.plan,
                "status": status,
                "billing_cycle": billing_cycle,
                "mrr_usd": round(mrr, 2),
                "arr_usd": round(mrr * 12, 2),
                "start_date": start_date.date().isoformat(),
                "canceled_at": cancel_date,
            }
        )

        current_month = pd.Timestamp(start_date).to_period("M").to_timestamp()
        end_month = END_DATE.to_period("M").to_timestamp()

        while current_month <= end_month:
            if cancel_date and current_month > pd.Timestamp(cancel_date):
                break

            invoice_amount = mrr if billing_cycle == "monthly" else mrr * 12
            if billing_cycle == "annual" and current_month.month != start_date.month:
                current_month += pd.DateOffset(months=1)
                continue

            due_date = current_month + pd.Timedelta(days=15)
            is_paid = status != "past_due" or rng.random() > 0.45
            paid_at = due_date + pd.Timedelta(days=rng.randint(-5, 10)) if is_paid else None

            inv_id = f"inv_{invoice_id:06d}"

            invoices.append(
                {
                    "invoice_id": inv_id,
                    "subscription_id": sub_id,
                    "billing_customer_id": customer_id,
                    "account_id": deal.account_id,
                    "invoice_date": current_month.date().isoformat(),
                    "due_date": due_date.date().isoformat(),
                    "amount_due_usd": round(invoice_amount, 2),
                    "status": "paid" if is_paid else "open",
                }
            )

            if is_paid:
                payments.append(
                    {
                        "payment_id": f"pay_{payment_id:06d}",
                        "invoice_id": inv_id,
                        "billing_customer_id": customer_id,
                        "account_id": deal.account_id,
                        "payment_date": paid_at.date().isoformat(),
                        "amount_paid_usd": round(invoice_amount, 2),
                        "payment_method": weighted_choice(rng, ["card", "bank_transfer", "wire"], [0.62, 0.28, 0.10]),
                    }
                )
                payment_id += 1

            invoice_id += 1
            current_month += pd.DateOffset(months=1)

        subscription_id += 1

    return (
        pd.DataFrame(customers),
        pd.DataFrame(subscriptions),
        pd.DataFrame(invoices),
        pd.DataFrame(payments),
    )


def build_product_events(subscriptions: pd.DataFrame, rng: Random) -> pd.DataFrame:
    event_types = [
        "login",
        "dashboard_viewed",
        "report_created",
        "integration_connected",
        "user_invited",
        "export_downloaded",
    ]
    rows: list[dict[str, Any]] = []
    event_id = 1

    for sub in subscriptions.itertuples(index=False):
        start = pd.Timestamp(sub.start_date)
        end = pd.Timestamp(sub.canceled_at) if isinstance(sub.canceled_at, str) and sub.canceled_at else END_DATE
        end = min(end, END_DATE)

        if start > END_DATE or end < start:
            continue

        months_active = max(1, (end.to_period("M") - start.to_period("M")).n + 1)

        if sub.status == "active":
            activity_multiplier = weighted_choice(rng, ["low", "medium", "high"], [0.25, 0.50, 0.25])
        elif sub.status == "past_due":
            activity_multiplier = weighted_choice(rng, ["low", "medium", "high"], [0.55, 0.35, 0.10])
        else:
            activity_multiplier = weighted_choice(rng, ["low", "medium", "high"], [0.70, 0.25, 0.05])

        monthly_events = {"low": rng.randint(2, 8), "medium": rng.randint(9, 25), "high": rng.randint(26, 60)}[activity_multiplier]
        total_events = months_active * monthly_events

        for _ in range(total_events):
            occurred_at = random_date(rng, start, min(end, END_DATE))
            rows.append(
                {
                    "event_id": f"evt_{event_id:08d}",
                    "account_id": sub.account_id,
                    "subscription_id": sub.subscription_id,
                    "user_id": f"user_{rng.randint(1, 5000):05d}",
                    "event_type": weighted_choice(rng, event_types, [0.45, 0.22, 0.12, 0.06, 0.10, 0.05]),
                    "occurred_at": occurred_at.isoformat(),
                }
            )
            event_id += 1

    return pd.DataFrame(rows)


def build_support_tickets(subscriptions: pd.DataFrame, rng: Random) -> pd.DataFrame:
    severities = ["low", "medium", "high", "critical"]
    statuses = ["open", "pending", "resolved", "closed"]
    categories = ["billing", "bug", "how_to", "integration", "performance", "feature_request"]

    rows: list[dict[str, Any]] = []
    ticket_id = 1

    for sub in subscriptions.itertuples(index=False):
        start = pd.Timestamp(sub.start_date)
        end = pd.Timestamp(sub.canceled_at) if isinstance(sub.canceled_at, str) and sub.canceled_at else END_DATE
        end = min(end, END_DATE)

        if start > END_DATE or end < start:
            continue
        if sub.status == "past_due":
            n_tickets = rng.randint(3, 12)
        elif sub.status == "canceled":
            n_tickets = rng.randint(2, 10)
        else:
            n_tickets = rng.randint(0, 7)

        for _ in range(n_tickets):
            created_at = random_date(rng, start, end)
            severity = weighted_choice(rng, severities, [0.45, 0.35, 0.15, 0.05])
            status = weighted_choice(rng, statuses, [0.10, 0.10, 0.55, 0.25])

            resolved_at = ""
            if status in {"resolved", "closed"}:
                resolution_days = {
                    "low": rng.randint(1, 5),
                    "medium": rng.randint(2, 10),
                    "high": rng.randint(5, 20),
                    "critical": rng.randint(1, 7),
                }[severity]
                resolved_at = (created_at + pd.Timedelta(days=resolution_days)).isoformat()

            rows.append(
                {
                    "ticket_id": f"tck_{ticket_id:06d}",
                    "account_id": sub.account_id,
                    "subscription_id": sub.subscription_id,
                    "created_at": created_at.isoformat(),
                    "resolved_at": resolved_at,
                    "status": status,
                    "severity": severity,
                    "category": weighted_choice(rng, categories, [0.18, 0.20, 0.22, 0.18, 0.10, 0.12]),
                }
            )
            ticket_id += 1

    return pd.DataFrame(rows)


def main() -> None:
    fake = Faker()
    Faker.seed(SEED)

    rng = Random(SEED)
    np.random.seed(SEED)

    accounts = build_accounts(fake, rng)
    contacts = build_contacts(accounts, fake, rng)
    deals = build_deals(accounts, rng)
    billing_customers, subscriptions, invoices, payments = build_billing(accounts, deals, rng)
    product_events = build_product_events(subscriptions, rng)
    support_tickets = build_support_tickets(subscriptions, rng)

    write_csv(accounts, "crm_accounts.csv")
    write_csv(contacts, "crm_contacts.csv")
    write_csv(deals, "crm_deals.csv")
    write_csv(billing_customers, "billing_customers.csv")
    write_csv(subscriptions, "billing_subscriptions.csv")
    write_csv(invoices, "billing_invoices.csv")
    write_csv(payments, "billing_payments.csv")
    write_csv(product_events, "product_events.csv")
    write_csv(support_tickets, "support_tickets.csv")

    print("\nSynthetic data generation completed.")


if __name__ == "__main__":
    main()