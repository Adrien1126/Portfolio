DROP FUNCTION IF EXISTS CALCULATE_DAY_COUNT_FACTOR;
DELIMITER //
CREATE FUNCTION CALCULATE_DAY_COUNT_FACTOR(
    d1 DATE,
    d2 DATE,
    d3 DATE,
    freq VARCHAR(50),
    convention VARCHAR(50)
)
RETURNS DECIMAL(20,8)
DETERMINISTIC
BEGIN
    DECLARE days INT;
    DECLARE act INT;
    DECLARE days_in_year INT;
    DECLARE factor DECIMAL(20,8);
    DECLARE d1_day INT;
    DECLARE d2_day INT;
    DECLARE frequency_value INT;
    
    -- Conversion de la fréquence en valeur numérique
    CASE UPPER(freq)
        WHEN 'ANNUAL' THEN SET frequency_value = 1;
        WHEN 'SEMI ANNUAL' THEN SET frequency_value = 2;
        WHEN 'QUARTER' THEN SET frequency_value = 4;
        ELSE SET frequency_value = NULL;
    END CASE;
    
    -- Si la fréquence n'est pas valide, retourner NULL
    IF frequency_value IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Calcul du nombre de jours entre les dates
    SET days = DATEDIFF(d2, d1);
    SET act = DATEDIFF(d3,d1);
    
    CASE convention
        -- ISMA-30/360 avec ajustement des jours 31
        WHEN 'ISMA-30/360' THEN
            -- Ajustement des jours 31 à 30
            SET d1_day = DAY(d1);
            SET d2_day = DAY(d2);
            
            -- Si le jour est 31, on le ramène à 30
            IF d1_day = 31 THEN
                SET d1_day = 30;
            END IF;
            IF d2_day = 31 THEN
                SET d2_day = 30;
            END IF;
            
            SET factor = (360*(YEAR(d2)-YEAR(d1))+30*(MONTH(d2)-MONTH(d1))+(d2_day-d1_day))/360;
            
        -- ACT/360
        WHEN 'ACT/360' THEN
            SET factor = days / 360;
            
        -- ACT/365
        WHEN 'ACT/365' THEN
            SET factor = days / 365;
            
        -- ACT/ACT
        WHEN 'ACT/ACT' THEN
            SET factor = days/(365*frequency_value);
            
        ELSE 
            SET factor = NULL;
    END CASE;
    
    RETURN factor;
END //
DELIMITER ;