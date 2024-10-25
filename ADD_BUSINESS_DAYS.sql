DELIMITER //

CREATE FUNCTION ADD_BUSINESS_DAYS(start_date DATE, add_days INTEGER)
RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE counter INT DEFAULT 0;
    DECLARE curr_date DATE;
    SET curr_date = start_date;
    
    WHILE counter < add_days DO
        SET curr_date = DATE_ADD(curr_date, INTERVAL 1 DAY);
        IF DAYOFWEEK(curr_date) NOT IN (1, 7) THEN -- 1 = Sunday, 7 = Saturday
            SET counter = counter + 1;
        END IF;
    END WHILE;
    
    RETURN curr_date;
END //

DELIMITER ;

