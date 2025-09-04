# Catalyst

Catalyst is a **portfolio manager** built with [Phoenix LiveView](https://www.phoenixframework.org/) as a way for me to learn Elixir and explore building real-time applications.  
⚠️ This is a learning project — expect bugs, rough edges, and unfinished features.

⚠️ Poorly documented as for personal use only
---

## ✨ Features

- 📈 **Market Data Sync**  
  - Fetches market data nightly from the stock market using [Oban](https://hex.pm/packages/oban) background jobs.
  - ability to upload market data through csv import incase nightly job failed / historic data for admin user. 
  - bulk import incase zip of multiple days is provided for admin user.
  - selective instruments tracking through config.
    ```ex
       config :catalyst,instruments: ["TICKER_A","TICKER_B"]
    ```

- 💹 **Trading & Transactions**  
  Supports trades and cash transactions with automatic balance tracking.

- 📊 **Portfolio Calculations**  
  - Rolling balances  
  - Notional value  
  - Actual profit/loss tracking
  - The balance,notional profits and actual profits are cached for fast evaluation (memoization).

- 👤 **User Roles & Authentication**  
  Role-based access for `users` and `admins`.
  - proper separtion of user as prescribed in [Ecto](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html#connection-prefixes)
  - ets indexing on same user_id to ensure no mixing of data

- 📅 **Market Holiday Awareness**  
  - Skips or adjusts for trading holidays.
  - cached with ets (eventually consistent) as common for all users.
  - Ability for admin to load csv for year through live_upload

- 📉 **Visualizations**  
  Interactive charts powered by [Chart.js](https://www.chartjs.org/) and LiveView hooks.

- ⚡ **Realtime Validations**  
  Inline feedback for trade forms and transactions.

---

## 🚧 Status

This application was created as a **learning project** to deepen my understanding of Elixir, Phoenix LiveView, and real-time web applications.  
It is **not production-ready**, and there are likely bugs, missing tests, and incomplete features.

Tests around core calculations around balance and notional profits are present
balance_holding_test.exs

CRUD tests for changesets present 

Pending :
Liveview tests 

---

## 🛠 Tech Stack

- [Elixir](https://elixir-lang.org/)  
- [Phoenix Framework](https://www.phoenixframework.org/)  
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)  
- [Oban](https://hex.pm/packages/oban)  
- [Chart.js](https://www.chartjs.org/)

---

## 🚀 Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/your-username/catalyst.git
   cd catalyst
````

2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Setup the database: 
    NOTE: you may have to set password to "postgres" in config/test and config/dev

   ```bash
   mix ecto.setup
   ```

4. Start the server:

   ```bash
   mix phx.server
   ```

5. Visit [http://localhost:4000](http://localhost:4000)
    login using "user@example.com", "sample_password" credentials


