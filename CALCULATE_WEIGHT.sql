DROP FUNCTION IF EXISTS CALCULATE_WEIGHT;
DELIMITER //

CREATE FUNCTION CALCULATE_WEIGHT(
    instrument_type VARCHAR(50),
    quantity DECIMAL(18,6),
    close_price DECIMAL(18,6),
    Mf DECIMAL(18,6),
    fx_rate DECIMAL(18,6),
    market_value DECIMAL(18,6),
    AUM DECIMAL(18,6)
)
RETURNS DECIMAL(18,6)
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN AUM = 0 THEN NULL  -- Eviter la division par zéro
        WHEN instrument_type = 'Future Contract' THEN quantity * close_price * Mf * fx_rate / AUM
        ELSE market_value / AUM
    END;
END //

DELIMITER ;
