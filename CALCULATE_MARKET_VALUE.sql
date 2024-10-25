DROP FUNCTION IF EXISTS CALCULATE_MARKET_VALUE;
DELIMITER //

CREATE FUNCTION CALCULATE_MARKET_VALUE(
    instrument_type VARCHAR(50),
    quantity DECIMAL(18,6),
    close_price DECIMAL(18,6),
    fx_rate DECIMAL(18,6),
    Mo DECIMAL(18,6),
    Mf DECIMAL(18,6),
    Fixed_coupon DECIMAL(18,6),
    day_count_factor DECIMAL(18,6)
)
RETURNS DECIMAL(18,0)
DETERMINISTIC
BEGIN
    RETURN 
		CASE
			WHEN instrument_type = 'Stock' THEN quantity * close_price * COALESCE(fx_rate, 1)
			WHEN instrument_type = 'Future Contract' THEN 0  -- MV pour les futures est 0 ici
			WHEN instrument_type = 'Option' THEN quantity * close_price * fx_rate * Mo * Mf
            WHEN instrument_type = 'Debt' THEN (quantity * (close_price + Fixed_coupon*day_count_factor)*fx_rate)/100
			ELSE quantity * close_price * COALESCE(fx_rate, 1)
		END;
END //

DELIMITER ;
