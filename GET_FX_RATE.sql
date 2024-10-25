DROP FUNCTION IF EXISTS GET_FX_RATE;
DELIMITER //
CREATE FUNCTION GET_FX_RATE(
    source_currency VARCHAR(3),
    target_currency VARCHAR(3),
    reference_date DATE,
    provider VARCHAR(50)
)
RETURNS DECIMAL(20,10)
DETERMINISTIC
BEGIN
    DECLARE fx_rate DECIMAL(20,10);
    DECLARE inverse_rate DECIMAL(20,10);
    
    -- Cas 1: Même devise
    IF source_currency = target_currency THEN
        RETURN 1.0;
    END IF;
    
    -- Cas 2: Conversion directe
    SELECT tq.close INTO fx_rate
    FROM foreign_exchange fx
    JOIN v_ticker_quote tq ON fx.instrument_id = tq.instrument_id
    WHERE fx.foreign_currency = source_currency
    AND fx.domestic_currency = target_currency
    AND tq.provider_name = provider
    AND DATE(tq.timestamp) = reference_date
    AND tq.currency_code = target_currency
    LIMIT 1;
    
    IF fx_rate IS NOT NULL THEN
        RETURN fx_rate;
    END IF;
    
    -- Cas 3: Conversion inverse
    SELECT tq.close INTO inverse_rate
    FROM foreign_exchange fx
    JOIN v_ticker_quote tq ON fx.instrument_id = tq.instrument_id
    WHERE fx.foreign_currency = target_currency
    AND fx.domestic_currency = source_currency
    AND tq.provider_name = provider
    AND DATE(tq.timestamp) = reference_date
    AND tq.currency_code = source_currency
    LIMIT 1;
    
    IF inverse_rate IS NOT NULL AND inverse_rate != 0 THEN
        RETURN 1 / inverse_rate;
    END IF;
    
    -- Cas 4: Conversion via EUR comme devise pivot
    IF target_currency != 'EUR' AND source_currency != 'EUR' THEN
        SET fx_rate = (
            SELECT GET_FX_RATE(source_currency, 'EUR', reference_date, provider) * 
                   GET_FX_RATE('EUR', target_currency, reference_date, provider)
        );
        
        IF fx_rate IS NOT NULL THEN
            RETURN fx_rate;
        END IF;
    END IF;
    
    -- Si aucun taux n'est trouvé, retourner NULL
    RETURN NULL;
END //
DELIMITER ;