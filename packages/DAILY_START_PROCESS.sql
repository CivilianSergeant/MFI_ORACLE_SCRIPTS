CREATE OR REPLACE PACKAGE MFIDSK.DAILY_START_PROCESS
AS
 PROCEDURE ADD_WEEKLY_SAVING_TRX(createDate Date, createUser varchar, 
 	weekDay varchar, officeID number, orgID number);
 PROCEDURE ADD_LTS_SAVING_TRX(createDate Date, createUser varchar, 
 	weekDay varchar, officeID number, orgID number);
 PROCEDURE ADD_WEEKLY_LOAN_TRX(createDate Date, createUser varchar, 
 	weekDay varchar, officeID number, orgID number);
 PROCEDURE ADD_MONTHLY_LOAN_TRX(createDate Date, createUser varchar, 
 	weekDay varchar, officeID number, orgID number);
 PROCEDURE UPDATE_LOAN_PAID(officeID number);
 PROCEDURE RESET_LOAN_INT_PAID_DUE(officeID NUMBER, orgID NUMBER);
 PROCEDURE DELETE_HOLIDAY_RECORDS(officeID NUMBER, orgID NUMBER,businessDate DATE);
 PROCEDURE DELETE_EXPIRE_LOAN_ACCOUNTS(officeID NUMBER);
 PROCEDURE DELETE_EXPIRED_FAMILY_GRACE_ACCOUNTS(officeID NUMBER,businessDate DATE);
 PROCEDURE UPDATE_LOAN_FOR_LIFT_LOAN(officeID NUMBER,businessDate DATE);
 PROCEDURE UPDATE_LOAN_FOR_JCF(officeID NUMBER, orgID NUMBER, businessDate DATE);
 PROCEDURE UPDATE_LOAN_FOR_LAST_INSTALLMENT(officeID NUMBER, orgID NUMBER, businessDate DATE);
 PROCEDURE RESET_PARTIAL_AMOUNT(officeID NUMBER, orgID NUMBER);
 PROCEDURE DELETE_TEMP_DATA(officeID NUMBER, businessDate DATE);
END DAILY_START_PROCESS;

CREATE OR REPLACE PACKAGE BODY MFIDSK.DAILY_START_PROCESS
AS
PROCEDURE ADD_WEEKLY_SAVING_TRX(
createDate IN DATE,
createUser IN varchar,
weekDay IN varchar,
officeID IN NUMBER,
orgID IN NUMBER
) IS 
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [ADD_WEEKLY_SAVING_TRX]:';
BEGIN
	/**
	 * GET RESULT WHEN INSTALLMENT_DATE IS NOT WITHIN THE MONTH FROM LOAN SUMMARY
	 * LEFT JOIN WITH SAVING SUMMARY
	 * AND MEMBER ID IS NULL WITHIN LOAN_SUMMARY
	 **/
	BEGIN
	INSERT INTO DAILY_SAVING_TRX
		(SAVING_SUMMARY_ID, OFFICE_ID, MEMBER_ID,
			PRODUCT_ID, CENTER_ID, NO_OF_ACCOUNT,	
			TRANSACTION_DATE, DUE_SAVING_INSTALLMENT, SAVING_INSTALLMENT,
			DEPOSIT, WITHDRAWAL, BALANCE,
			PENALTY, TRANS_TYPE, MONTHLY_INTEREST,
			PRESENCE_IND, TRANSFER_DEPOSIT,	TRANSFER_WITHDRAWAL,
			MEMBER_CODE,MEMBER_NAME, EMPLOYEE_ID, MEMBER_CATEGORY_ID,
			PRODUCT_CODE, PRODUCT_NAME,	CREATE_USER,
			CREATE_DATE, ORGANIZATION_ID, CUR_INTEREST 
		)SELECT s.SAVING_SUMMARY_ID, s.OFFICE_ID, s.MEMBER_ID,
			s.PRODUCT_ID, s.CENTER_ID, s.NO_OF_ACCOUNT,
			s.TRANSACTION_DATE AS TRANSACTION_DATE,
			s.SAVING_INSTALLMENT AS DUE_SAVING_INSTALLMENT,s.SAVING_INSTALLMENT,
			s.DEPOSIT, 0 WITHDRAWAL, (s.DEPOSIT+s.CUM_INTEREST-s.WITHDRAWAL) AS BALANCE,
			0 PENALTY, 10 TRANS_TYPE, 0 AS MONTHLY_INTEREST, 1 AS PRESENCE_IND,	
			s.CUM_INTEREST AS TRANSFER_DEPOSIT , s.WITHDRAWAL AS TRANSFER_WITHDRAWAL,
			m.MEMBER_CODE ,	GET_MEMBER_NAME(m.MEMBER_ID,'name') AS MEMBER_NAME, s.EMPLOYEE_ID,
			m.MEMBER_CATEGORY_ID, p.PRODUCT_CODE , GET_PRODUCT_NAME(p.PRODUCT_ID,'name') AS PRODUCT_NAME,
			createUser AS CREATE_USER, createDate AS CREATE_DATE, 
			s.ORGANIZATION_ID , s.MONTHLY_INTEREST AS CUR_INTEREST
			FROM SAVING_SUMMARY s 
			INNER JOIN CENTERS c ON c.CENTER_ID=s.CENTER_ID AND c.OFFICE_ID=s.OFFICE_ID
			INNER JOIN PRODUCTS p ON s.PRODUCT_ID =p.PRODUCT_ID
			INNER JOIN MEMBERS m ON s.MEMBER_ID=m.MEMBER_ID AND s.OFFICE_ID=m.OFFICE_ID and s.CENTER_ID=m.CENTER_ID
			LEFT JOIN (
				SELECT l.OFFICE_ID,l.CENTER_ID,l.MEMBER_ID
				FROM LOAN_SUMMARY l 
				INNER JOIN PRODUCTS p on l.PRODUCT_ID=p.PRODUCT_ID
				INNER JOIN CENTERS c on l.CENTER_ID=c.CENTER_ID and l.OFFICE_ID=c.OFFICE_ID
				INNER JOIN MEMBERS m on l.MEMBER_ID=m.MEMBER_ID and l.OFFICE_ID=m.OFFICE_ID and l.CENTER_ID=m.CENTER_ID
				WHERE l.OFFICE_ID=officeID
				AND l.ORGANIZATION_ID=orgID
				AND (l.INSTALLMENT_DATE<UTIL.GET_FIRST_DATE(createDate)
					OR  l.INSTALLMENT_DATE>UTIL.GET_LAST_DATE(createDate) )
				AND l.LOAN_STATUS=1
				AND l.INSTALLMENT_NO<l.DURATION
				AND l.INSTALLMENT_START_DATE<=createDate
				AND l.IS_ACTIVE=1
				AND l.DISBURSE_DATE IS NOT NULL
				AND c.COLLECTION_DAY=weekDay
				AND p.PAYMENT_FREQUENCY='M') l ON s.OFFICE_ID=l.OFFICE_ID AND s.CENTER_ID=l.CENTER_ID and s.MEMBER_ID=l.MEMBER_ID
			WHERE s.OFFICE_ID=officeID
			AND s.ORGANIZATION_ID=orgID
			AND s.SAVING_STATUS=1 -- 1 is for Active
			AND s.IS_ACTIVE=1
			AND c.COLLECTION_DAY=weekDay
			AND p.PAYMENT_FREQUENCY='W'
			AND l.MEMBER_ID IS NULL;
		
	EXCEPTION
		WHEN OTHERS THEN
		WRITE_LOG(spName || SQLERRM);
		raise_application_error(-20001,spName || SQLERRM);
	
	END;
	
	/**
	 * GET RESULT WHEN INSTALLMENT_DATE IS NOT WITHIN THE MONTH FROM LOAN SUMMARY
	 * INNER JOIN WITH SAVING SUMMARY
	 * AND PRODUCT MAIN CODE = 21
	 */
	BEGIN
	INSERT INTO DAILY_SAVING_TRX
		(SAVING_SUMMARY_ID, OFFICE_ID, MEMBER_ID,
			PRODUCT_ID, CENTER_ID, NO_OF_ACCOUNT,	
			TRANSACTION_DATE, DUE_SAVING_INSTALLMENT, SAVING_INSTALLMENT,
			DEPOSIT, WITHDRAWAL, BALANCE,
			PENALTY, TRANS_TYPE, MONTHLY_INTEREST,
			PRESENCE_IND, TRANSFER_DEPOSIT,	TRANSFER_WITHDRAWAL,
			MEMBER_CODE,MEMBER_NAME, EMPLOYEE_ID, MEMBER_CATEGORY_ID,
			PRODUCT_CODE, PRODUCT_NAME,	CREATE_USER,
			CREATE_DATE, ORGANIZATION_ID, CUR_INTEREST 
		)SELECT s.SAVING_SUMMARY_ID, s.OFFICE_ID, s.MEMBER_ID,
			s.PRODUCT_ID, s.CENTER_ID, s.NO_OF_ACCOUNT,
			createDate AS TRANSACTION_DATE,
			s.SAVING_INSTALLMENT AS DUE_SAVING_INSTALLMENT,s.SAVING_INSTALLMENT,
			s.DEPOSIT, 0 WITHDRAWAL, (s.DEPOSIT+s.CUM_INTEREST-s.WITHDRAWAL) AS BALANCE,
			0 PENALTY, 10 TRANS_TYPE, 0 AS MONTHLY_INTEREST, 1 AS PRESENCE_IND,	
			s.CUM_INTEREST AS TRANSFER_DEPOSIT , s.WITHDRAWAL AS TRANSFER_WITHDRAWAL,
			m.MEMBER_CODE ,	GET_MEMBER_NAME(m.MEMBER_ID,'name') AS MEMBER_NAME, s.EMPLOYEE_ID,
			m.MEMBER_CATEGORY_ID, p.PRODUCT_CODE , GET_PRODUCT_NAME(p.PRODUCT_ID,'name') AS PRODUCT_NAME,
			createUser AS CREATE_USER, createDate AS CREATE_DATE, 
			s.ORGANIZATION_ID , s.MONTHLY_INTEREST AS CUR_INTEREST
			FROM SAVING_SUMMARY s 
			INNER JOIN CENTERS c ON c.CENTER_ID=s.CENTER_ID AND c.OFFICE_ID=s.OFFICE_ID
			INNER JOIN PRODUCTS p ON s.PRODUCT_ID =p.PRODUCT_ID
			INNER JOIN MEMBERS m ON s.MEMBER_ID=m.MEMBER_ID AND s.OFFICE_ID=m.OFFICE_ID and s.CENTER_ID=m.CENTER_ID
			INNER JOIN (
				SELECT l.OFFICE_ID,l.CENTER_ID,l.MEMBER_ID
				FROM LOAN_SUMMARY l 
				INNER JOIN PRODUCTS p on l.PRODUCT_ID=p.PRODUCT_ID
				INNER JOIN CENTERS c on l.CENTER_ID=c.CENTER_ID and l.OFFICE_ID=c.OFFICE_ID
				INNER JOIN MEMBERS m on l.MEMBER_ID=m.MEMBER_ID and l.OFFICE_ID=m.OFFICE_ID and l.CENTER_ID=m.CENTER_ID
				WHERE l.OFFICE_ID=officeID
				AND l.ORGANIZATION_ID=orgID
				AND (l.INSTALLMENT_DATE < UTIL.GET_FIRST_DATE(createDate) 
					OR  l.INSTALLMENT_DATE > UTIL.GET_LAST_DATE(createDate) )
				AND l.LOAN_STATUS=1
				AND l.INSTALLMENT_NO<l.DURATION
				AND l.INSTALLMENT_START_DATE<=createDate
				AND l.IS_ACTIVE=1
				AND l.DISBURSE_DATE IS NOT NULL
				AND c.COLLECTION_DAY=GET_WEEK_DAY(createDate)
				AND p.PAYMENT_FREQUENCY='M') l ON s.OFFICE_ID=l.OFFICE_ID AND s.CENTER_ID=l.CENTER_ID and s.MEMBER_ID=l.MEMBER_ID
			WHERE s.OFFICE_ID=officeID
			AND s.ORGANIZATION_ID=orgID
			AND s.SAVING_STATUS=1 -- 1 is for Active
			AND s.IS_ACTIVE=1
			AND c.COLLECTION_DAY=weekDay
			AND p.PAYMENT_FREQUENCY='W'
			AND SUBSTR(p.MAIN_PRODUCT_CODE,0,2) = '21';
		
	EXCEPTION
		WHEN OTHERS THEN
		WRITE_LOG(spName || SQLERRM);
		raise_application_error(-20001,spName || SQLERRM);
	END;
    
	WRITE_LOG('END WEEKLY SAVING TRX');

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

	
END;
/**
 * ADD LTS RECORDS TO DAILY SAVING TRX FOR
 * MEMBERS WHO HAS DPS PRODUCT
 */
PROCEDURE ADD_LTS_SAVING_TRX(
createDate IN Date,
createUser IN varchar,
weekDay IN varchar,
officeID IN NUMBER,
orgID IN NUMBER
) IS 
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [ADD_LTS_SAVING_TRX]:';
BEGIN
	INSERT INTO DAILY_SAVING_TRX
		(SAVING_SUMMARY_ID, OFFICE_ID, MEMBER_ID,
				PRODUCT_ID, CENTER_ID, NO_OF_ACCOUNT,	
				TRANSACTION_DATE, DUE_SAVING_INSTALLMENT, SAVING_INSTALLMENT,
				DEPOSIT, WITHDRAWAL, BALANCE,
				PENALTY, TRANS_TYPE, MONTHLY_INTEREST,
				PRESENCE_IND, TRANSFER_DEPOSIT,	TRANSFER_WITHDRAWAL,
				MEMBER_CODE,MEMBER_NAME, EMPLOYEE_ID, MEMBER_CATEGORY_ID,
				PRODUCT_CODE, PRODUCT_NAME,	CREATE_USER,
				CREATE_DATE, ORGANIZATION_ID
			)SELECT s.SAVING_SUMMARY_ID, s.OFFICE_ID, s.MEMBER_ID,
			s.PRODUCT_ID, s.CENTER_ID, s.NO_OF_ACCOUNT,
			createDate AS TRANSACTION_DATE,
			s.SAVING_INSTALLMENT AS DUE_SAVING_INSTALLMENT,s.SAVING_INSTALLMENT,
			s.DEPOSIT, 0 WITHDRAWAL, (s.DEPOSIT+s.CUM_INTEREST-s.WITHDRAWAL) AS BALANCE,
			0 PENALTY, 10 TRANS_TYPE, 0 AS MONTHLY_INTEREST, 1 AS PRESENCE_IND,	
			s.CUM_INTEREST AS TRANSFER_DEPOSIT , s.WITHDRAWAL AS TRANSFER_WITHDRAWAL,
			m.MEMBER_CODE ,	GET_MEMBER_NAME(m.MEMBER_ID,'name') AS MEMBER_NAME, s.EMPLOYEE_ID,
			m.MEMBER_CATEGORY_ID, p.PRODUCT_CODE , GET_PRODUCT_NAME(p.PRODUCT_ID,'name') AS PRODUCT_NAME,
			createUser AS CREATE_USER, createDate AS CREATE_DATE, 
			s.ORGANIZATION_ID 
			FROM SAVING_SUMMARY s 
			INNER JOIN CENTERS c on c.CENTER_ID=s.CENTER_ID and c.OFFICE_ID=s.OFFICE_ID
			INNER JOIN PRODUCTS p on s.PRODUCT_ID=p.PRODUCT_ID
			INNER JOIN MEMBERS m on s.MEMBER_ID=m.MEMBER_ID and s.OFFICE_ID=m.OFFICE_ID and s.CENTER_ID=m.CENTER_ID
			INNER JOIN (
				SELECT DISTINCT OFFICE_ID,CENTER_ID,MEMBER_ID,INSTALLMENT_DATE 
					FROM DAILY_LOAN_TRX l 	
					INNER JOIN PRODUCTS p ON l.PRODUCT_ID=p.PRODUCT_ID
			 		WHERE OFFICE_ID=officeID AND INSTALLMENT_DATE=createDate
			 	) l ON s.OFFICE_ID=l.OFFICE_ID AND s.CENTER_ID=l.CENTER_ID AND  s.MEMBER_ID=l.MEMBER_ID
			WHERE	s.OFFICE_ID=officeID 
					And s.ORGANIZATION_ID=4
					And s.SAVING_STATUS=1 -- 1 is for Active
					And s.IS_ACTIVE=1
					and c.COLLECTION_DAY=weekDay
					and p.PAYMENT_FREQUENCY='M'
					and l.INSTALLMENT_DATE=createDate
					And p.SUB_MAIN_CATEGORY='DPS';
				
			WRITE_LOG('END LTS SAVING TRX');
				
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;
/**
 * Add weekly daily loan
 */
PROCEDURE ADD_WEEKLY_LOAN_TRX(
createDate IN Date,
createUser IN varchar,
weekDay IN varchar,
officeID IN NUMBER,
orgID IN NUMBER
) IS 
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [ADD_WEEKLY_LOAN_TRX]:';
BEGIN
	INSERT INTO DAILY_LOAN_TRX
		(TRX_DATE , LOAN_SUMMARY_ID,	OFFICE_ID,
		MEMBER_ID, PRODUCT_ID, CENTER_ID, MEMBER_CATEGORY_ID,
		LOAN_TERM, PURPOSE_ID, INSTALLMENT_DATE, PRINCIPAL_LOAN,
		LOAN_REPAID, LOAN_DUE, LOAN_PAID, CUM_INT_CHARGE,
		INT_CHARGE,	INT_DUE, INT_PAID, ADVANCE, DUE_RECOVERY,
		TRX_TYPE, INSTALLMENT_NO, EMPLOYEE_ID, MEMBER_CODE,
		MEMBER_NAME, PRODUCT_CODE, PRODUCT_NAME,
		INTEREST_CALCULATION_METHOD, INVESTOR_ID,
		CREATE_USER, CREATE_DATE, LOAN_NO, ORGANIZATION_ID,
		DURATION, 
		DURATION_OVER_LOAN_DUE, -- loan_installment
		DURATION_OVER_INT_DUE -- interest_installment
		)
SELECT createDate AS TRX_DATE, l.LOAN_SUMMARY_ID , l.OFFICE_ID,
	 l.MEMBER_ID, l.PRODUCT_ID, l.CENTER_ID, l.MEMBER_CATEGORY_ID,
	 l.LOAN_TERM, l.PURPOSE_ID, createDate Installment_Date,
	 l.PRINCIPAL_LOAN, l.LOAN_REPAID, 
	 COALESCE(MFI_CALCULATION.GET_LOAN_DUE(p.INTEREST_CALCULATION_METHOD,
	 	l.PRINCIPAL_LOAN,l.LOAN_REPAID,l.LOAN_INSTALLMENT,l.INT_INSTALLMENT,
	 	l.INTEREST_RATE,l.INT_CHARGE,p.PAYMENT_FREQUENCY,
	 	l.INT_PAID,l.INSTALLMENT_DATE,createDate),0) AS LOAN_DUE,
 	 COALESCE(MFI_CALCULATION.GET_LOAN_PAID(p.INTEREST_CALCULATION_METHOD,
	 	l.PRINCIPAL_LOAN,l.LOAN_REPAID,l.LOAN_INSTALLMENT,l.INT_INSTALLMENT,
	 	l.INTEREST_RATE,l.INT_CHARGE,p.PAYMENT_FREQUENCY,
	 	l.INT_PAID,l.INSTALLMENT_DATE,createDate),0) AS LOAN_PAID,
 	 COALESCE(MFI_CALCULATION.GET_CUM_INT_CHARGE(p.INTEREST_CALCULATION_METHOD, 
	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY,
	 	l.INSTALLMENT_DATE, createDate),0) AS CUM_INT_CHARGE, 
 	 COALESCE(MFI_CALCULATION.GET_INT_CHARGE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.INTEREST_RATE, p.PAYMENT_FREQUENCY,
 		l.INSTALLMENT_DATE, createDate),0) INT_CHARGE,
 	 COALESCE(MFI_CALCULATION.GET_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
 		l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
 		l.INSTALLMENT_NO, l.DURATION, createDate),0) INT_DUE,
	 COALESCE(MFI_CALCULATION.GET_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
 		l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
 		l.INSTALLMENT_NO, l.DURATION, createDate),0) INT_PAID,
	 	l.ADVANCE, l.INT_PAID AS DUE_RECOVERY, 10 AS TRX_TYPE,
	 	CASE WHEN (createDate < l.INSTALLMENT_START_DATE) THEN l.INSTALLMENT_NO 
	 	ELSE (l.INSTALLMENT_NO+1) END AS INSTALLMENT_NO,l.EMPLOYEE_ID, m.MEMBER_CODE,
	 	GET_MEMBER_NAME(m.MEMBER_ID,'name') AS MEMBER_NAME,p.PRODUCT_CODE, GET_PRODUCT_NAME(p.PRODUCT_ID,'') PRODUCT_NAME,
	 	p.INTEREST_CALCULATION_METHOD, l.INVESTOR_ID,createUser AS CREATE_USER ,createDate CREATE_DATE,
	 	l.LOAN_NO,l.ORGANIZATION_ID,l.DURATION, 
 	COALESCE(MFI_CALCULATION.GET_DURATION_OVER_LOAN_DUE(p.INTEREST_CALCULATION_METHOD, 
	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
	 	l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
	 	createDate),0) AS DURATION_OVER_LOAN_DUE, 
 	COALESCE(MFI_CALCULATION.GET_DURATION_OVER_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
	 	l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
	 	l.INSTALLMENT_NO, l.DURATION, createDate),0) DURATION_OVER_INT_DUE
	 	FROM LOAN_SUMMARY l 
		INNER JOIN PRODUCTS p ON l.PRODUCT_ID=p.PRODUCT_ID
		INNER JOIN CENTERS c ON l.CENTER_ID=c.CENTER_ID and l.OFFICE_ID=c.OFFICE_ID
		INNER JOIN MEMBERS m ON l.MEMBER_ID=m.MEMBER_ID and l.OFFICE_ID=m.OFFICE_ID and l.CENTER_ID=m.CENTER_ID
		WHERE l.OFFICE_ID=officeID
		AND l.ORGANIZATION_ID=orgID
		AND l.IS_ACTIVE=1
		AND l.LOAN_STATUS=1
		AND c.COLLECTION_DAY=weekDay
	 AND (p.PAYMENT_FREQUENCY ='W' OR p.PAYMENT_FREQUENCY = 'M')
		AND  l.LOAN_SUMMARY_ID NOT IN (
			SELECT l.LOAN_SUMMARY_ID FROM LOAN_SUMMARY l 
				WHERE l.INSTALLMENT_NO=0 AND l.INSTALLMENT_START_DATE > createDate 
				AND l.OFFICE_ID=officeID AND l.IS_ACTIVE=1
			) AND l.DISBURSE_DATE IS NOT NULL;
		
	WRITE_LOG('END WEEKLY LOAN TRX');
		
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;
/**
 * add monthly loan
 */
PROCEDURE ADD_MONTHLY_LOAN_TRX(
createDate IN Date,
createUser IN varchar,
weekDay IN varchar,
officeID IN NUMBER,
orgID IN NUMBER
) IS 
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [ADD_MONTHLY_LOAN_TRX]:';
BEGIN
	INSERT INTO DAILY_LOAN_TRX
		(TRX_DATE , LOAN_SUMMARY_ID,	OFFICE_ID,
		MEMBER_ID, PRODUCT_ID, CENTER_ID, MEMBER_CATEGORY_ID,
		LOAN_TERM, PURPOSE_ID, INSTALLMENT_DATE, PRINCIPAL_LOAN,
		LOAN_REPAID, LOAN_DUE, LOAN_PAID, CUM_INT_CHARGE,
		INT_CHARGE,	INT_DUE, INT_PAID, ADVANCE, DUE_RECOVERY,
		TRX_TYPE, INSTALLMENT_NO, EMPLOYEE_ID, MEMBER_CODE,
		MEMBER_NAME, PRODUCT_CODE, PRODUCT_NAME,
		INTEREST_CALCULATION_METHOD, INVESTOR_ID,
		CREATE_USER, CREATE_DATE, LOAN_NO, ORGANIZATION_ID,
		DURATION
		--,DURATION_OVER_LOAN_DUE, -- loan_installment
		--DURATION_OVER_INT_DUE -- interest_installment
		)
SELECT createDate AS TRX_DATE, l.LOAN_SUMMARY_ID , l.OFFICE_ID,
	 l.MEMBER_ID, l.PRODUCT_ID, l.CENTER_ID, l.MEMBER_CATEGORY_ID,
	 l.LOAN_TERM, l.PURPOSE_ID, createDate Installment_Date,
	 l.PRINCIPAL_LOAN, l.LOAN_REPAID, 
	 COALESCE(MFI_CALCULATION.GET_LOAN_DUE(p.INTEREST_CALCULATION_METHOD,
	 	l.PRINCIPAL_LOAN,l.LOAN_REPAID,l.LOAN_INSTALLMENT,l.INT_INSTALLMENT,
	 	l.INTEREST_RATE,l.INT_CHARGE,p.PAYMENT_FREQUENCY,
	 	l.INT_PAID,l.INSTALLMENT_DATE,createDate),0) AS LOAN_DUE,
 	 COALESCE(MFI_CALCULATION.GET_LOAN_PAID(p.INTEREST_CALCULATION_METHOD,
	 	l.PRINCIPAL_LOAN,l.LOAN_REPAID,l.LOAN_INSTALLMENT,l.INT_INSTALLMENT,
	 	l.INTEREST_RATE,l.INT_CHARGE,p.PAYMENT_FREQUENCY,
	 	l.INT_PAID,l.INSTALLMENT_DATE,createDate),0) AS LOAN_PAID,
 	 COALESCE(MFI_CALCULATION.GET_CUM_INT_CHARGE(p.INTEREST_CALCULATION_METHOD, 
	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY,
	 	l.INSTALLMENT_DATE, createDate),0) AS CUM_INT_CHARGE, 
 	 COALESCE(MFI_CALCULATION.GET_INT_CHARGE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.INTEREST_RATE, p.PAYMENT_FREQUENCY,
 		l.INSTALLMENT_DATE, createDate),0) INT_CHARGE,
 	 COALESCE(MFI_CALCULATION.GET_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
 		l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
 		l.INSTALLMENT_NO, l.DURATION, createDate),0) INT_DUE,
	 COALESCE(MFI_CALCULATION.GET_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
 		l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
 		l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
 		l.INSTALLMENT_NO, l.DURATION, createDate),0) INT_PAID,
	 	l.ADVANCE, l.INT_PAID AS DUE_RECOVERY, 10 AS TRX_TYPE,
	 	CASE WHEN (createDate < l.INSTALLMENT_START_DATE) THEN l.INSTALLMENT_NO 
	 	ELSE (l.INSTALLMENT_NO+1) END AS INSTALLMENT_NO,l.EMPLOYEE_ID, m.MEMBER_CODE,
	 	GET_MEMBER_NAME(m.MEMBER_ID,'name') AS MEMBER_NAME,p.PRODUCT_CODE, GET_PRODUCT_NAME(p.PRODUCT_ID,'') PRODUCT_NAME,
	 	p.INTEREST_CALCULATION_METHOD, l.INVESTOR_ID,createUser AS CREATE_USER ,createDate CREATE_DATE,
	 	l.LOAN_NO,l.ORGANIZATION_ID,l.DURATION
-- 	,COALESCE(MFI_CALCULATION.GET_DURATION_OVER_LOAN_DUE(p.INTEREST_CALCULATION_METHOD, 
--	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
--	 	l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
--	 	createDate),0) AS DURATION_OVER_LOAN_DUE, 
-- 	COALESCE(MFI_CALCULATION.GET_DURATION_OVER_INT_DUE(p.INTEREST_CALCULATION_METHOD, 
--	 	l.PRINCIPAL_LOAN, l.LOAN_REPAID, l.LOAN_INSTALLMENT, l.INT_INSTALLMENT, 
--	 	l.INTEREST_RATE, l.INT_CHARGE, p.PAYMENT_FREQUENCY, l.INT_PAID, l.INSTALLMENT_DATE,
--	 	l.INSTALLMENT_NO, l.DURATION, createDate),0) DURATION_OVER_INT_DUE
	 	FROM LOAN_SUMMARY l 
		INNER JOIN PRODUCTS p ON l.PRODUCT_ID=p.PRODUCT_ID
		INNER JOIN CENTERS c ON l.CENTER_ID=c.CENTER_ID and l.OFFICE_ID=c.OFFICE_ID
		INNER JOIN MEMBERS m ON l.MEMBER_ID=m.MEMBER_ID and l.OFFICE_ID=m.OFFICE_ID and l.CENTER_ID=m.CENTER_ID
		WHERE l.OFFICE_ID=officeID
		AND l.ORGANIZATION_ID=orgID
		AND l.IS_ACTIVE=1
		AND l.LOAN_STATUS=1
		AND c.COLLECTION_DAY=weekDay
		AND (l.INSTALLMENT_DATE < UTIL.GET_FIRST_DATE(createDate)
			OR l.INSTALLMENT_DATE> UTIL.GET_LAST_DATE(createDate))
		AND l.INSTALLMENT_NO < l.DURATION
		AND l.INSTALLMENT_START_DATE < createDate
		AND l.DISBURSE_DATE IS NOT NULL;
		
	WRITE_LOG('END WEEKLY LOAN TRX');
		
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;
/**
 * Update loan paid if (installment+1) == duration then 
 * set principal balance otherwise as it is
 */
PROCEDURE UPDATE_LOAN_PAID(officeID IN NUMBER) 
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [UPDATE_LOAN_PAID]:';
BEGIN
	
	UPDATE (SELECT (Case When t2.INSTALLMENT_NO + 1 = t2.DURATION 
			Then (t1.PRINCIPAL_LOAN-t1.LOAN_REPAID) ELSE t1.LOAN_PAID END) LOAN_PAID_SRC,
			t1.LOAN_PAID LOAN_PAID_TARGET
			From DAILY_LOAN_TRX t1,LOAN_SUMMARY t2
			WHERE t1.OFFICE_ID = t2.OFFICE_ID 
				And t1.CENTER_ID = t2.CENTER_ID
				And t1.MEMBER_ID = t2.MEMBER_ID 
				And t1.PRODUCT_ID = t2.PRODUCT_ID 
				And t1.LOAN_TERM = t2.LOAN_TERM
				And t1.LOAN_SUMMARY_ID=t2.LOAN_SUMMARY_ID
				And t1.OFFICE_ID=officeID)
			SET LOAN_PAID_TARGET = LOAN_PAID_SRC;
		
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);
END;
/**
 * IF Installment No greater or equal to loan duration
 * then Update loan due, int due, loan paid,int paid to 0
 */
PROCEDURE RESET_LOAN_INT_PAID_DUE(officeID NUMBER, orgID NUMBER)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [RESET_LOAN_INT_PAID_DUE]:';
BEGIN
	
	UPDATE (SELECT DAILY_LOAN_TRX_ID, d.LOAN_DUE AS LOAN_DUE,d.INT_DUE,d.LOAN_PAID,d.INT_PAID 
		FROM DAILY_LOAN_TRX d 
			INNER JOIN LOAN_SUMMARY l ON d.OFFICE_ID = l.OFFICE_ID AND 
	      		d.CENTER_ID = l.CENTER_ID AND d.MEMBER_ID = l.MEMBER_ID AND 
	      		d.PRODUCT_ID = l.PRODUCT_ID AND d.LOAN_TERM = l.LOAN_TERM
		  AND l.LOAN_SUMMARY_ID = d.LOAN_SUMMARY_ID
		  INNER JOIN PRODUCTS p ON d.PRODUCT_ID=p.PRODUCT_ID
		  WHERE d.OFFICE_ID=officeID AND d.ORGANIZATION_ID=orgID
			AND l.INSTALLMENT_NO>=l.DURATION AND l.LOAN_STATUS=1 AND p.PAYMENT_FREQUENCY='W')
		  SET LOAN_DUE=0,INT_DUE=0,LOAN_PAID=0,INT_PAID=0;
		 
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);
END;

PROCEDURE DELETE_HOLIDAY_RECORDS(officeID NUMBER, orgID NUMBER,businessDate DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [HOLIDAY_RECORDS]:';
CURSOR cur IS 
		SELECT DISTINCT h.Center_ID FROM Holidays h INNER JOIN Daily_Loan_Trx dlc 
	ON h.Office_ID = dlc.Office_ID AND h.Center_ID = dlc.Center_ID 
			 Where  dlc.Office_ID = officeID AND dlc.ORGANIZATION_ID=orgID
			AND (h.Business_Date = businessDate)
		AND h.HOLIDAY_TYPE='Office';
	
	TYPE class IS RECORD (center_id NUMBER(19));
	TYPE records IS TABLE OF class INDEX BY BINARY_INTEGER;
	v_records records;

BEGIN
	OPEN cur;

	FETCH cur BULK COLLECT INTO v_records;

	IF(v_records.COUNT>0) THEN
	
		FOR obj IN 1..v_records.COUNT LOOP
		
		DELETE FROM DAILY_LOAN_TRX WHERE (DAILY_LOAN_TRX.OFFICE_ID = officeID AND ORGANIZATION_ID=orgID)  
				AND DAILY_LOAN_TRX.CENTER_ID=v_records(obj).center_id;

		dbms_output.put_line('record deleted from daily_loan_trx where center_id ' || v_records(obj).center_id);
	
		DELETE FROM   DAILY_SAVING_TRX  WHERE  (DAILY_SAVING_TRX.OFFICE_ID = officeID And ORGANIZATION_ID=orgID) 
				AND DAILY_SAVING_TRX.CENTER_ID=v_records(obj).center_id;
			
		dbms_output.put_line('record deleted from daily_saving_trx where center_id ' || v_records(obj).center_id);
			
	END LOOP;

	END IF;

	CLOSE cur;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;
/**
 * Delete expire loan accounts
 */
PROCEDURE DELETE_EXPIRE_LOAN_ACCOUNTS(officeID NUMBER)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [DELETE_EXPIRE_LOAN_ACCOUNTS]:';
CURSOR cur IS
		Select ei.Office_ID,ei.Center_ID,ei.Member_ID
		 From Expire_Infos ei 
		 INNER JOIN LOAN_SUMMARY l ON ei.Office_ID = l.OFFICE_ID
		 	AND ei.Center_ID = l.CENTER_ID AND ei.MEMBER_ID = l.MEMBER_ID 
		 Where ei.Expire_Date>l.Disburse_Date AND l.Disburse_Date is not null
		GROUP BY ei.Office_ID,ei.Center_ID,ei.Member_ID
		Having (ei.Office_ID = officeID );
	
	TYPE class IS RECORD (office_id NUMBER(19),center_id NUMBER(19),member_id NUMBER(32));
	TYPE records IS TABLE OF class INDEX BY BINARY_INTEGER;
	v_records records;

BEGIN
	
	OPEN cur;

	FETCH cur BULK COLLECT INTO v_records;

	IF(v_records.COUNT>0) THEN
	
		FOR i IN 1..v_records.COUNT LOOP
		
		DELETE FROM Daily_Loan_Trx WHERE Office_ID=v_records(i).office_id 
			AND Center_ID=v_records(i).center_id AND Member_ID=v_records(i).member_id;
			
		dbms_output.put_line('record deleted from Daily_Loan_Trx where center_id ' || v_records(i).center_id
		|| ' member_id: ' || v_records(i).member_id);
	
		END LOOP;
	
	END IF;
	CLOSE cur;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;

PROCEDURE DELETE_EXPIRED_FAMILY_GRACE_ACCOUNTS(officeID NUMBER,businessDate DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [DELETE_EXPIRED_FAMILY_GRACE_ACCOUNTS]:';
CURSOR cur IS
	SELECT dlc.MEMBER_ID,dlc.CENTER_ID From FAMILY_GRACE fg 
		INNER JOIN 
	         MEMBERS m ON fg.OFFICE_ID = m.OFFICE_ID AND fg.CENTER_ID = m.CENTER_ID 
	         AND fg.MEMBER_ID = m.MEMBER_ID 
	    INNER JOIN 
	         DAILY_LOAN_TRX dlc ON fg.OFFICE_ID = dlc.OFFICE_ID
	         AND fg.CENTER_ID = dlc.CENTER_ID AND fg.MEMBER_ID = dlc.MEMBER_ID 
	         WHERE (m.MARITAL_STATUS = 1) AND (dlc.OFFICE_ID = officeID) 
	         AND  (fg.GRACE_START_DATE <= businessDate) 
	         AND (fg.GRACE_END_DATE >= businessDate);
	        
		TYPE class IS RECORD (
			member_id NUMBER(32),
			center_id NUMBER(19)
		);
		TYPE records IS TABLE OF class INDEX BY BINARY_INTEGER;
		v_records records;
BEGIN

	OPEN cur;
	
	FETCH cur BULK COLLECT INTO v_records;
	IF(v_records.COUNT>0) THEN
		FOR i IN 1..v_records.COUNT LOOP
			DELETE FROM   DAILY_LOAN_TRX  WHERE  (OFFICE_ID = officeID)  
				AND CENTER_ID=v_records(i).center_id 
				AND MEMBER_ID=v_records(i).member_id;
				
			DELETE FROM DAILY_SAVING_TRX  WHERE  (OFFICE_ID = officeID) 
				AND CENTER_ID=v_records(i).center_id 
				AND MEMBER_ID=v_records(i).member_id;
		END LOOP;
	END IF;

	CLOSE cur;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;

PROCEDURE UPDATE_LOAN_FOR_LIFT_LOAN(officeID NUMBER,businessDate DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [UPDATE_LOAN_FOR_LIFT_LOAN]:';
BEGIN
	
	UPDATE (SELECT d.DAILY_LOAN_TRX_ID,d.LOAN_PAID,d.LOAN_DUE,d.INT_PAID,d.INT_DUE 
		FROM DAILY_LOAN_TRX d 
		INNER JOIN PRODUCTS p ON d.PRODUCT_ID=p.PRODUCT_ID
		INNER JOIN LOAN_SUMMARY l ON d.LOAN_SUMMARY_ID=l.LOAN_SUMMARY_ID
		and d.OFFICE_ID=l.OFFICE_ID and d.CENTER_ID=l.CENTER_ID
		and d.MEMBER_ID=l.MEMBER_ID and d.PRODUCT_ID=l.PRODUCT_ID
		and d.LOAN_TERM=l.LOAN_TERM
		WHERE d.OFFICE_ID=officeID 
		AND d.INSTALLMENT_DATE=businessDate
		AND SUBSTR(p.MAIN_PRODUCT_CODE,2)='11' 
		AND (l.INSTALLMENT_NO+1)<=(l.DURATION/2))
	SET LOAN_PAID=0,LOAN_DUE=0,INT_PAID=0,INT_DUE=0;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;

PROCEDURE UPDATE_LOAN_FOR_JCF(officeID IN NUMBER, orgID IN NUMBER, businessDate IN DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [UPDATE_LOAN_FOR_JCF]:';
BEGIN
	
	Update (SELECT d.DAILY_LOAN_TRX_ID,d.INT_CHARGE,
		d.CUM_INT_CHARGE, l.INT_CHARGE l_int_charge
		FROM DAILY_LOAN_TRX d 
		INNER JOIN PRODUCTS p ON d.PRODUCT_ID=p.PRODUCT_ID
		INNER JOIN LOAN_SUMMARY l ON d.LOAN_SUMMARY_ID=l.LOAN_SUMMARY_ID
		AND d.OFFICE_ID=l.OFFICE_ID AND d.CENTER_ID=l.CENTER_ID
		AND d.MEMBER_ID=l.MEMBER_ID AND d.PRODUCT_ID=l.PRODUCT_ID
		AND d.LOAN_TERM=l.LOAN_TERM
		WHERE d.OFFICE_ID=officeID AND d.INSTALLMENT_DATE=businessDate
		AND l.INSTALLMENT_NO>=l.DURATION AND l.ORGANIZATION_ID=orgID)
	SET INT_CHARGE=0,CUM_INT_CHARGE=l_int_charge;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;
/**
 * UPDATE LOAN FOR LAST INSTALLMENT
 */
PROCEDURE UPDATE_LOAN_FOR_LAST_INSTALLMENT(officeID NUMBER, orgID NUMBER, businessDate DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [UPDATE_LOAN_FOR_LAST_INSTALLMENT]:';
BEGIN
	
	UPDATE (
	SELECT dl.DAILY_LOAN_TRX_ID,dl.LOAN_PAID,dl.LOAN_DUE,dl.INT_PAID,dl.INT_DUE,
	l.LOAN_PAID L_PAID,l.LOAN_DUE L_DUE,(dl.CUM_INT_CHARGE-l.INT_DUE) L_INT_PAID,
	(dl.CUM_INT_CHARGE-l.INT_DUE) L_INT_DUE
	FROM DAILY_LOAN_TRX dl 
			INNER JOIN (
			SELECT ul.ORGANIZATION_ID, ul.INSTALLMENT_NO,ul.DURATION, ul.LOAN_SUMMARY_ID, 
			ul.OFFICE_ID,ul.CENTER_ID,ul.MEMBER_ID,ul.PRODUCT_ID,ul.LOAN_TERM,
		    (ul.PRINCIPAL_LOAN-ul.CUM_LOAN_DUE) Loan_Paid,
			(ul.PRINCIPAL_LOAN-ul.CUM_LOAN_DUE) Loan_Due,
			ul.CUM_INT_DUE INT_DUE,ul.MEMBER_CATEGORY_ID,ul.EMPLOYEE_ID,
			ul.INVESTOR_ID
			 FROM LOAN_SUMMARY ul  
			 ) l ON dl.LOAN_SUMMARY_ID=l.LOAN_SUMMARY_ID
			WHERE dl.OFFICE_ID=officeID AND dl.INSTALLMENT_DATE=businessDate 
			AND dl.INSTALLMENT_NO=l.DURATION  AND l.OFFICE_ID=officeID 
			AND l.ORGANIZATION_ID=orgID
	)
	SET LOAN_PAID=L_PAID,
		LOAN_DUE=L_DUE,
		INT_PAID=L_INT_PAID,
		INT_DUE=L_INT_DUE;
	
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;

PROCEDURE RESET_PARTIAL_AMOUNT(officeID IN NUMBER, orgID IN NUMBER)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [RESET_PARTIAL_AMOUNT]:';
BEGIN
	
	UPDATE LOAN_SUMMARY
	SET PARTIAL_AMOUNT=0,
		PARTIAL_INT_CHARGE=0,
		PARTIAL_INT_PAID=0
	WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID  
	AND IS_ACTIVE=1 and DISBURSEMENT_TYPE=2;
	
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);
END;

PROCEDURE DELETE_TEMP_DATA(officeID IN NUMBER, businessDate IN DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [DELETE_TEMP_DATA]:';
BEGIN
	
	DELETE FROM COLLECTION_LOAN_SAVINGS WHERE OFFICE_ID=officeID 
	AND COLLECTION_DATE=businessDate;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);
END;	
END DAILY_START_PROCESS;