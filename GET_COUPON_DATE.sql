DROP FUNCTION IF EXISTS GET_COUPON_DATE;

DELIMITER //

CREATE FUNCTION GET_COUPON_DATE(first_payment_date DATE, reference_date DATE, coupon_type VARCHAR(50), frequency VARCHAR(20), direction VARCHAR(10))
RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE interval_months INT;
    DECLARE curr_date DATE;  -- Utilisation de curr_date au lieu de current_date
    
    -- Définir l'intervalle en mois selon la fréquence
    SET interval_months = CASE 
        WHEN frequency = 'Annual' THEN 12
        WHEN frequency = 'Semi Annual' THEN 6
        WHEN frequency = 'Quarter' THEN 3
        ELSE 12 -- Par défaut annuel
    END;
    
    -- Commencer à partir de la première date de paiement
    SET curr_date = first_payment_date;  
    
    -- Si on cherche la date après (d3)
    IF direction = 'AFTER' THEN
        WHILE curr_date <= reference_date DO  
            SET curr_date = DATE_ADD(curr_date, INTERVAL interval_months MONTH);
        END WHILE;
    -- Si on cherche la date avant (d1)
    ELSE
        WHILE DATE_ADD(curr_date, INTERVAL interval_months MONTH) <= reference_date DO  
            SET curr_date = DATE_ADD(curr_date, INTERVAL interval_months MONTH);
        END WHILE;
	END IF;
        
	IF coupon_type = 'Floating' THEN
		IF DAYOFWEEK(curr_date) = 7 THEN
            SET curr_date = DATE_ADD(curr_date, INTERVAL 2 DAY);
        -- Si curr_date tombe un dimanche, ajouter 1 jour (lundi)
        ELSEIF DAYOFWEEK(curr_date) = 1 THEN
            SET curr_date = DATE_ADD(curr_date, INTERVAL 1 DAY);
		END IF;
	END IF;
    -- Retourner la date calculée 
	return curr_date; 
END //

DELIMITER ;