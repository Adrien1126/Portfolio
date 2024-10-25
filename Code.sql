WITH raw_data AS (
    -- Étape 1: Récupération des données brutes avec fx_rate simplifié
    SELECT 
        p.instrument_code AS Code,                     
        p.instrument_id AS Instrument_id,
        p.instrument_name AS Name,                   
        p.quantity AS Quantity,                      
        p.type AS Type,
        d.coupon_day_count AS CC_day_count,
        d.days_to_settle AS CC_days_to_settle,
        d.first_payment_date AS CC_first_payment_date,
        d.interest_accrual_date AS CC_interest_accrual_debt,
        d.fixed_coupon_value AS CC_fixed_coupon_value,
        d.coupon_frequency AS CC_frequency,
        d.coupon_type as CCType,
        d.floating_coupon_reference_id AS floating_coupon_reference_id,
        d.spread AS spread,
        d.reference_prior_days AS reference_prior_days,
        d.floor AS floor,
        d.main_coupon_type AS pre_coupon_type,
        d.variable_coupon_main_coupon_id AS pre_coupon_id,
        d.variable_coupon_switch_date AS switch_date,
        d.new_coupon_type AS new_coupon_type,
        d.variable_coupon_new_coupon_id AS new_coupon_id,
        -- Obtention du prix close de chaque instrument
        CASE                                         
            WHEN p.instrument_id = 27321 THEN 100    
            ELSE q.close                             
        END AS Close,                                
        p.instrument_currency AS Currency,           
        -- Fonction pour obtenir le taux de change fx_rate
        GET_FX_RATE(
            p.instrument_currency, 
            'EUR',  -- devise cible
            '2018-10-04',  -- date de référence
            'bloomberg'  -- provider
        ) AS fx_rate,
        -- Obtention de Mf
        CASE 
            WHEN p.type = 'Future Contract' THEN COALESCE(f.point_value, 1)  
            WHEN p.type = 'Option' AND v.underlying_id IS NOT NULL THEN COALESCE(f.point_value, 1)  
            ELSE 1  
        END AS Mf,  
        aum.close AS AUM,  
        v.contract_unit AS Mo, 
        v.underlying_id AS underlying_id,
        v.strike AS Strike,
        v.expiration_date AS Expiration_date,
        v.option_type AS TypeOption,
        v.underlying_type AS UnderlyingType,
        v.underlying_name AS Underlying_Name,
        -- Ajout d'une jointure pour obtenir le prix de clôture de l'underlying
        uq.close AS Underlying_Close -- Prix de clôture de l'underlying
    FROM 
        v_fund_position p
    LEFT JOIN 
        v_ticker_quote q 
        ON p.instrument_id = q.instrument_id         
        AND DATE(q.timestamp) = '2018-10-04'         
        AND q.provider_name = 'bloomberg'            
    LEFT JOIN 
        v_option v                                    
        ON p.instrument_id = v.option_id              
    LEFT JOIN 
        v_future_contract f                           
        ON (p.instrument_id = f.future_contract_id    
            OR v.underlying_id = f.future_contract_id)
    LEFT JOIN 
        v_ticker_quote aum                           
        ON p.fund_id = aum.instrument_id
        AND aum.provider_name = 'bloomberg'
        AND DATE(aum.timestamp) = '2018-10-04'
    LEFT JOIN 
        v_debt d
        ON p.instrument_id = d.debt_id
	LEFT JOIN 
        v_ticker_quote uq  -- Jointure avec v_ticker_quote pour l'underlying
        ON v.underlying_id = uq.instrument_id
        AND DATE(uq.timestamp) = '2018-10-04'  -- Prix à la date souhaitée
    WHERE 
        p.position_date = '2018-10-04'	
        AND p.fund_name = 'ENSIIE Portfolio'
),

call_put_parity AS (
    SELECT
        rd.*, 
        -- Récupérer l'option associée avec un CASE
        CASE 
            WHEN rd.Type = 'Option' THEN (
                SELECT tq.close
                FROM v_ticker_quote tq
                WHERE tq.instrument_id = rd.instrument_id + 1
                AND DATE(tq.timestamp) = '2018-10-04'
                AND tq.provider_name = 'bloomberg'
            )
            ELSE NULL 
        END AS Close_Associated_option
    FROM raw_data rd
),

time_to_maturity AS (
    SELECT 
        cpp.*,
        -- Calcul de la différence en mois entre expiration_date et la date de référence
        DATEDIFF(expiration_date, '2018-10-04')/30.0 AS months_to_expiration
    FROM call_put_parity cpp
),

euribor_rates AS (
    SELECT 
        ttm.*,
        -- Récupérer le taux Euribor inférieur le plus proche
        (
            SELECT rcs.instrument_id
            FROM v_rate_curve_structure rcs
            WHERE rcs.instrument_code LIKE 'IND_EURIBOR_%MONTH'
            AND rcs.currency = 'EUR'
            AND rcs.pillar <= ttm.months_to_expiration
            ORDER BY rcs.pillar DESC
            LIMIT 1
        ) as lower_euribor_id,
        -- Récupérer le taux Euribor supérieur le plus proche
        (
            SELECT rcs.instrument_id
            FROM v_rate_curve_structure rcs
            WHERE rcs.instrument_code LIKE 'IND_EURIBOR_%MONTH'
            AND rcs.currency = 'EUR'
            AND rcs.pillar > ttm.months_to_expiration
            ORDER BY rcs.pillar ASC
            LIMIT 1
        ) as upper_euribor_id,
        -- Récupérer les pillar correspondants
        (
            SELECT rcs.pillar
            FROM v_rate_curve_structure rcs
            WHERE rcs.instrument_id = lower_euribor_id
        ) as lower_pillar,
        (
            SELECT rcs.pillar
            FROM v_rate_curve_structure rcs
            WHERE rcs.instrument_id = upper_euribor_id
        ) as upper_pillar
    FROM time_to_maturity ttm
),

euribor_values AS (
    SELECT 
        er.*,
        -- Récupérer les valeurs des taux
        (
            SELECT tq.close
            FROM v_ticker_quote tq
            WHERE tq.instrument_id = er.lower_euribor_id
            AND DATE(tq.timestamp) = '2018-10-04'
            AND tq.provider_name = 'bloomberg'
        ) as lower_close,
        (
            SELECT tq.close
            FROM v_ticker_quote tq
            WHERE tq.instrument_id = er.upper_euribor_id
            AND DATE(tq.timestamp) = '2018-10-04'
            AND tq.provider_name = 'bloomberg'
        ) as upper_close
    FROM euribor_rates er
),


-- Il faut ajouter un bloc variable_coupon_type qui renvoie fixed si le coupon est fixe, floating si le coupon est floating 
-- et pour les variables, il va déterminer en fonction de la switch date le type de coupon
-- Cette valeur nous permettra de l'utiliser correctement pour calculer les dates de coupon en remplacant CCType par la variable 
-- variable_coupon_type, néanmoins il faut gérer le cas où si on est avant la switch date et que le coupon est quand meme variable 
-- on le fait de manière récursive

dates_calculation AS (
    -- Étape 2: Calcul des dates d1, d2 et d3
    SELECT 
        *,
        -- Calcul de la différence en jours entre la date d'expiration et le 2018-10-04
        DATEDIFF(Expiration_date, '2018-10-04')/365 AS Days_To_Expiration,
        -- On s'assure que d2 tombe un jour ouvré avec ADD_BUSINESS_DAY
        ADD_BUSINESS_DAYS(DATE('2018-10-04'), CC_days_to_settle) AS d2,
        -- Gestion du cas où le premier coupon n'a pas été édité
        CASE 
            WHEN (ADD_BUSINESS_DAYS(DATE('2018-10-04'), CC_days_to_settle) < CC_first_payment_date) 
            THEN CC_interest_accrual_debt
            -- Sinon on récupère la date du précedent coupon 
            ELSE GET_COUPON_DATE(CC_first_payment_date, ADD_BUSINESS_DAYS(DATE('2018-10-04'), CC_days_to_settle), CCType, CC_frequency, 'BEFORE') 
        END AS d1,
        GET_COUPON_DATE(CC_first_payment_date, ADD_BUSINESS_DAYS(DATE('2018-10-04'), CC_days_to_settle), CCType, CC_frequency, 'AFTER') AS d3
    FROM euribor_values
), 

rates AS (
    -- Étape 3: Récupération des taux
    SELECT 
        dc.*,
        CASE 
            WHEN dc.CCType = 'FLOATING' THEN 
                (SELECT tq.close 
                 FROM v_ticker_quote tq
                 WHERE tq.instrument_id = dc.floating_coupon_reference_id
                 AND DATE(tq.timestamp) = SUB_BUSINESS_DAYS(dc.d1,dc.reference_prior_days)
                 AND tq.provider_name = 'bloomberg'
                 LIMIT 1)
            ELSE NULL
        END as floating_rate_close,
        vf.coupon_value
    FROM dates_calculation dc
    LEFT JOIN 
		v_fixed_coupon vf
		ON dc.pre_coupon_id = vf.fixed_coupon_id
),

-- day_count_factor : dépend seulement de la convention
day_count_calculation AS (
    -- Étape 4: Calcul du day_count_factor
    SELECT 
        *,
        CALCULATE_DAY_COUNT_FACTOR(d1, d2, d3, CC_frequency, CC_day_count) AS day_count_factor
    FROM rates
),

market_value_calculation AS (
    -- Étape 5: Calcul de la Market Value
    SELECT 
        *,
        CASE 
            WHEN CCType = 'Floating' THEN 
                GREATEST(
                    COALESCE(floating_rate_close + spread/100, 0),
                    COALESCE(floor, floating_rate_close + spread/100, 0)
                )
			WHEN CCType = 'Variable' THEN coupon_value
            ELSE CC_fixed_coupon_value 
        END as effective_coupon_rate,
        CALCULATE_MARKET_VALUE(
            Type, 
            Quantity, 
            Close, 
            fx_rate, 
            Mo, 
            Mf, 
            CASE 
                WHEN CCType = 'Floating' THEN 
                    GREATEST(
                        COALESCE(floating_rate_close + spread/100, 0),
                        COALESCE(floor, floating_rate_close + spread/100, 0)
                    )
				WHEN CCType = 'Variable' THEN coupon_value
                ELSE CC_fixed_coupon_value 
            END,
            day_count_factor
        ) AS MV
    FROM day_count_calculation
)


-- Étape finale: Calcul des poids
SELECT 
    code, 
    instrument_id,
    Name, 
    Quantity,
    close,
    Mo, 
    Mf,
	underlying_id,
    UnderlyingType,
    Underlying_Name,
    Underlying_Close,
	Strike,
	Expiration_date,
    months_to_expiration,
    lower_euribor_id,
    lower_pillar,
    lower_close,
    upper_euribor_id,
    upper_pillar,
    upper_close,
    Days_To_Expiration,
	TypeOption,
    Close_Associated_option,
    Type,
    MV,
    CALCULATE_WEIGHT(Type, Quantity, Close, Mf, fx_rate, MV, AUM) AS Weight
FROM market_value_calculation;
