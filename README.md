
# Market Value and Portfolio Weight Calculation for Financial Instruments

This SQL-based project provides a set of scripts for calculating the **Market Value (MV)** and **portfolio weights** of various financial instruments, incorporating detailed market parameters. A Black-Scholes model, implemented in `TP4Groupe4.ipynb`, is used to determine the **implied volatility** and **delta** of options—key values for precise weight calculations.

## Table of Contents

- [Context](#context)
- [Features](#features)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Key Functions and Calculations](#key-functions-and-calculations)
- [Contributing](#contributing)

## Context

This project is designed for investment funds that aim to automatically compute the market value and weight of each financial instrument in their portfolio, accounting for market conventions and discount rates.

## Features

- **Market Value Calculation**: Computes the market value of financial instruments (bonds, equities, options, futures).
- **Portfolio Weight Calculation**: Calculates the weight of instruments according to their type (bonds, equities, options, futures).
- **Implied Volatility and Delta Calculation**: Uses the Black-Scholes model in `TP4Groupe4.ipynb` to calculate option-specific values.
- **Day Conventions and Rate Adjustments**: Calculates coupon dates, adjusts dates to business days, and incorporates Euribor rates.

## Project Structure

- **ADD_BUSINESS_DAYS.sql**: SQL function to add a specified number of business days, used for floating and variable-rate bonds.
- **SUB_BUSINESS_DAYS.sql**: SQL function to subtract a specified number of business days.
- **GET_FX_RATE.sql**: Retrieves foreign exchange rates for different currencies.
- **GET_COUPON_DATE.sql**: Calculates coupon dates according to the instrument’s convention (fixed, floating, variable).
- **CALCULATE_DAY_COUNT_FACTOR.sql**: Computes the day-count factor for interest according to the day convention.
- **CALCULATE_MARKET_VALUE.sql**: Calculates the Market Value of each instrument; SQL code returns the aggregate Market Value for all instruments.
- **CALCULATE_WEIGHT.sql**: Calculates the weight of each instrument. The SQL code provides weights for stocks, bonds, and futures, while the Python code handles option weights due to the need for an options pricer.
- **TP4Groupe4.ipynb**: Jupyter notebook for calculating implied volatility and delta using the Black-Scholes model.
- **Code.sql**: Main script executing all calculation steps and incorporating SQL functions.

## Usage

To use this script, you’ll need a database that contains information on each financial instrument. You may also adapt this project for similar financial analyses.

## Key Functions and Calculations

### Implied Volatility and Delta (via Black-Scholes)

The `TP4Groupe4.ipynb` notebook implements the Black-Scholes model, enabling calculations for:

- **Euribor Rate**: Obtained by interpolation since Euribor rates are provided in specific monthly durations.
- **Implied Volatility**: Essential for accurately assessing the risk of options.
- **Delta**: Used to weight options in the portfolio’s weight calculations.

### Weight Calculations

Weights are calculated for each instrument based on its Market Value and delta (for options). The `CALCULATE_WEIGHT.sql` function combines these parameters, factoring in currency adjustments and aggregate Market Value (AUM).

## Possible improvement

The management of variable coupons was carried out in relation to my database. As a result, the recursive function for obtaining the coupon type at a given date was not implemented, given that all my coupons were fixed-rate at the portfolio valuation date. 
In addition, the structure of the code can certainly be improved. It is possible in some versions of SQL to integrate Python code directly. This was not the case for my version. 





