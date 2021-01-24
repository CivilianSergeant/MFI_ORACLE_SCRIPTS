CREATE OR REPLACE PROCEDURE MFIDSK.MONTHLY_CLOSING(
	officeID IN NUMBER,
	orgID IN NUMBER,
	monthEndDate IN DATE
) IS
msg VARCHAR2(255) := '';
isValid NUMBER(1) := 0;
spName varchar(80) := SYSDATE || ' MONTHLY_CLOSING: ';
vMaxProcessdate DATE;
vMaxHolidayDate DATE;
vProcessDate DATE;
vLastDate DATE;
vMaxClosingDate DATE;
countRecord NUMBER(32);
cMon NUMBER(19);
cYear NUMBER(19);
startMonth NUMBER(19);
startYear NUMBER(19);
vBranchName Varchar(50);
vMonthStartDate DATE;
totDay NUMBER(10);
intTotalDay NUMBER(10);

BEGIN
	SELECT UTIL.GET_LAST_DATE(monthEndDate) INTO vLastDate FROM DUAL;
	vProcessDate := vLastDate;

	SELECT MAX(CLOSING_DATE) INTO vMaxClosingDate
	FROM PROCESS_INFO WHERE OFFICE_ID=officeID AND CLOSING_STATUS=1 AND ORGANIZATION_ID=orgID;

	SELECT COUNT(*) INTO countRecord 
	FROM PROCESS_INFO 
	WHERE OFFICE_ID=officeID 
	AND BUSINESS_DATE<=monthEndDate AND CLOSING_STATUS=0;

	IF(countRecord <> 0) THEN
		msg := spName || 'Day closing Not completed for transaction date:' || monthEndDate;
		isValid := 1;
   		GOTO validation_point;
	END IF;

	cMon := UTIL.GET_MONTH_FROM_DATE(vProcessDate);
	cYear := UTIL.GET_YEAR_FROM_DATE(vProcessDate);

	SELECT MAX(BUSINESS_DATE) INTO vMaxHolidayDate
	FROM HOLIDAYS WHERE OFFICE_ID=officeID 
	AND  UTIL.GET_MONTH_FROM_DATE(BUSINESS_DATE)= cMon
	AND UTIL.GET_YEAR_FROM_DATE(BUSINESS_DATE)=cYear;

	IF(vMaxHolidayDate <> vMaxClosingDate) THEN
		msg:= spName || 'No Record for Transaction date 1: ' || vProcessDate;
		isValid :=1;
		GOTO validation_point;
	END IF;

	cMon  := UTIL.GET_MONTH_FROM_DATE(monthEndDate);
	cYear := UTIL.GET_YEAR_FROM_DATE(monthEndDate);
	vMonthStartDate := UTIL.GET_FIRST_DATE(monthEndDate);

	
	SELECT COUNT(*) 
	INTO countRecord 	
	FROM PROCESS_INFO 
	WHERE OFFICE_ID=officeID
	AND UTIL.GET_MONTH_FROM_DATE(MONTH_CLOSING_DATE)=cMon 
	AND MONTH_CLOSING_STATUS=1;
	
	IF(countRecord <> 0) THEN
		msg:= spName || 'Month closing Already completed for transaction date: ' || monthEndDate;
		isValid :=1;
		GOTO validation_point;
	END IF;

	

	DELETE FROM DAILY_LOAN_TRX WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID;
	
	DELETE FROM DAILY_SAVING_TRX WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID; 

	
	DELETE FROM NEW_AC_IN_7 WHERE OFFICE_ID = 6;
	DELETE FROM SAVING_TRANSACTION WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_SAVINGS_REGISTER WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_MONTHLY_PROCESS_1 WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_MONTHLY_PROCESS_2 WHERE OFFICE_ID = 6;
	DELETE FROM DAILY_SAVING_COLLECTION WHERE OFFICE_ID = 6;
	
	INSERT INTO SAVING_TRANSACTION (SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,
	CENTER_ID, MEMBER_ID, PRODUCT_ID, 
		BALANCE, TRANSACTION_DATE, 
		TRANSACTION_MONTH, 
	 TRANSACTION_YEAR, NO_OF_ACCOUNT)
	SELECT SAVING_TRX.SAVING_SUMMARY_ID,SAVING_TRX.ORGANIZATION_ID,SAVING_TRX.OFFICE_ID,
	SAVING_TRX.CENTER_ID, SAVING_TRX.MEMBER_ID, SAVING_TRX.PRODUCT_ID, 
		SAVING_TRX.BALANCE, SAVING_TRX.TRANSACTION_DATE, 
		UTIL.GET_MONTH_FROM_DATE(SAVING_TRX.TRANSACTION_DATE) TRANSACTION_MONTH, 
	 UTIL.GET_YEAR_FROM_DATE(SAVING_TRX.TRANSACTION_DATE) TRANSACTION_YEAR, SAVING_TRX.NO_OF_ACCOUNT
	FROM SAVING_TRX INNER JOIN SAVING_SUMMARY 
	ON SAVING_TRX.OFFICE_ID = SAVING_SUMMARY.OFFICE_ID 
		And SAVING_TRX.CENTER_ID = SAVING_SUMMARY.CENTER_ID 
		And SAVING_TRX.MEMBER_ID = SAVING_SUMMARY.MEMBER_ID 
		And SAVING_TRX.PRODUCT_ID = SAVING_SUMMARY.PRODUCT_ID 
		And SAVING_TRX.NO_OF_ACCOUNT = SAVING_SUMMARY.NO_OF_ACCOUNT
		And SAVING_TRX.SAVING_SUMMARY_ID = SAVING_SUMMARY.SAVING_SUMMARY_ID
	Where (SAVING_TRX.OFFICE_ID = 7 And SAVING_TRX.ORGANIZATION_ID=4) 
		And (UTIL.GET_MONTH_FROM_DATE(SAVING_TRX.TRANSACTION_DATE) = 10) 
		And (UTIL.GET_YEAR_FROM_DATE(SAVING_TRX.TRANSACTION_DATE) = 2019)
		And SAVING_SUMMARY.SAVING_STATUS = 1;
	
	
	INSERT INTO TEMP_SAVINGS_REGISTER(SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,
	CENTER_ID, MEMBER_ID, PRODUCT_ID, PERSONAL_SAVINGS, WITHDRAWAL, BALANCE, 
	TRANSACTION_DATE , NO_OF_ACCOUNT)
	SELECT st.SAVING_SUMMARY_ID,st.ORGANIZATION_ID,st.OFFICE_ID, st.CENTER_ID,
	st.MEMBER_ID, st.PRODUCT_ID, 
		SUM(st.DEPOSIT)+SUM(st.MONTHLY_INTEREST) PERSONAL_SAVINGS,
		SUM(st.WITHDRAWAL) WITHDRAWAL,
		SUM(st.BALANCE) BALANCE, 
		st.TRANSACTION_DATE , st.NO_OF_ACCOUNT
	FROM SAVING_TRX st 
	INNER JOIN SAVING_SUMMARY ss
	ON st.OFFICE_ID = ss.OFFICE_ID 
		AND st.CENTER_ID = ss.CENTER_ID 
		AND st.MEMBER_ID = ss.MEMBER_ID 
		AND st.PRODUCT_ID = ss.PRODUCT_ID
		AND st.NO_OF_ACCOUNT = ss.NO_OF_ACCOUNT 
		WHERE  st.OFFICE_ID = 6 AND st.ORGANIZATION_ID=4
		And (UTIL.GET_MONTH_FROM_DATE(st.TRANSACTION_DATE) = 10) 
		And (UTIL.GET_YEAR_FROM_DATE(st.TRANSACTION_DATE) = 2019)
		AND ss.SAVING_STATUS = 1
		GROUP BY st.OFFICE_ID, st.CENTER_ID, st.MEMBER_ID, st.PRODUCT_ID,
		st.NO_OF_ACCOUNT,st.TRANSACTION_DATE,st.ORGANIZATION_ID,st.SAVING_SUMMARY_ID;
	

	INSERT INTO TEMP_MONTHLY_PROCESS_1(
		SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,CENTER_ID,MEMBER_ID,PRODUCT_ID,BALANCE,
		PREVIOUS_BALANCE,TRANSACTION_DATE,TRANSACTION_DAY, NO_OF_ACCOUNT
	)
	SELECT tsr.SAVING_SUMMARY_ID,tsr.ORGANIZATION_ID,tsr.OFFICE_ID,tsr.CENTER_ID, 
		tsr.MEMBER_ID,tsr.PRODUCT_ID,tsr.BALANCE, 
		(tsr.BALANCE-tsr.PERSONAL_SAVINGS
		+tsr.WITHDRAWAL) AS PREVIOUS_BALANCE, 
		tsr.TRANSACTION_DATE, 
		UTIL.GET_DAY_FROM_DATE(TRANSACTION_DATE) AS TRANSACTION_DAY , tsr.NO_OF_ACCOUNT
		From TEMP_SAVINGS_REGISTER tsr
		WHERE (((tsr.OFFICE_ID)=6) 
		And ((tsr.BALANCE)>(tsr.BALANCE-tsr.PERSONAL_SAVINGS+tsr.WITHDRAWAL)) 
		And ((UTIL.GET_DAY_FROM_DATE(TRANSACTION_DATE))>7) 
		And ((UTIL.GET_MONTH_FROM_DATE(TRANSACTION_DATE))=10) 
		And ((UTIL.GET_YEAR_FROM_DATE(TRANSACTION_DATE))=2019))
		And tsr.ORGANIZATION_ID=4;
	
	
	INSERT INTO TEMP_MONTHLY_PROCESS_2(
		SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,CENTER_ID,MEMBER_ID,PRODUCT_ID,
		MIN_INSTALLMENT_DATE, NO_OF_ACCOUNT
	)
	SELECT SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID, CENTER_ID, MEMBER_ID, PRODUCT_ID ,
		MIN(TRANSACTION_DATE) As MIN_INSTALLMENT_DATE , NO_OF_ACCOUNT
		FROM TEMP_MONTHLY_PROCESS_1
	WHERE OFFICE_ID=6  AND ORGANIZATION_ID=4
	GROUP BY OFFICE_ID, CENTER_ID, MEMBER_ID,PRODUCT_ID ,NO_OF_ACCOUNT ,ORGANIZATION_ID,
	SAVING_SUMMARY_ID;

	
	INSERT INTO SAVING_TRANSACTION (SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,
	CENTER_ID, MEMBER_ID, PRODUCT_ID, 
		BALANCE, TRANSACTION_DATE, 
		TRANSACTION_MONTH, 
	 TRANSACTION_YEAR, NO_OF_ACCOUNT)
	SELECT t2.SAVING_SUMMARY_ID,t2.ORGANIZATION_ID,t2.OFFICE_ID, t2.CENTER_ID, 
		t2.MEMBER_ID, t2.PRODUCT_ID, 
		MIN(t1.PREVIOUS_BALANCE) AS MIN_PREVIOUS_BALANCE,
		TO_DATE('2019-10-01','YYYY-MM-DD') AS INSTALLMENT_DATE,10 TRANSACTION_MONTH,
		2019 TRANSACTION_YEAR, t2.NO_OF_ACCOUNT  
	FROM TEMP_MONTHLY_PROCESS_2 t2 LEFT JOIN TEMP_MONTHLY_PROCESS_1 t1  
	ON (t2.OFFICE_ID = t1.OFFICE_ID)  
	 	AND (t2.CENTER_ID = t1.CENTER_ID)  
		AND (t2.MEMBER_ID = t1.MEMBER_ID)  
		AND (t2.PRODUCT_ID = t1.PRODUCT_ID) 
		AND t2.NO_OF_ACCOUNT = t1.NO_OF_ACCOUNT
		AND (t2.MIN_INSTALLMENT_DATE = t1.TRANSACTION_DATE)  
		AND (t2.SAVING_SUMMARY_ID = t1.SAVING_SUMMARY_ID) 
	WHERE t2.OFFICE_ID=6 AND t2.ORGANIZATION_ID=4
	AND t1.OFFICE_ID=6
	GROUP BY t2.OFFICE_ID, t2.CENTER_ID, t2.SAVING_SUMMARY_ID,t2.ORGANIZATION_ID,
		t2.MEMBER_ID, t2.PRODUCT_ID,
		t1.TRANSACTION_DATE, t2.NO_OF_ACCOUNT;
	
	
	INSERT INTO DAILY_SAVING_TRX (SAVING_SUMMARY_ID, ORGANIZATION_ID,OFFICE_ID, CENTER_ID, 
	MEMBER_ID, PRODUCT_ID,BALANCE,TRANSACTION_DATE,NO_OF_ACCOUNT)
	SELECT st.SAVING_SUMMARY_ID,st.ORGANIZATION_ID,st.OFFICE_ID, st.CENTER_ID, 
		st.MEMBER_ID, st.PRODUCT_ID,   
		MIN(st.BALANCE) AS BALANCE, 
		MAX(st.TRANSACTION_DATE) AS TRANSACTION_DATE,
		st.NO_OF_ACCOUNT  
	FROM SAVING_TRANSACTION st INNER JOIN SAVING_SUMMARY ss 
	ON st.OFFICE_ID = ss.OFFICE_ID 
		AND  st.CENTER_ID = ss.CENTER_ID 
		AND st.MEMBER_ID = ss.MEMBER_ID 
		AND  st.PRODUCT_ID = ss.PRODUCT_ID 
		AND  st.TRANSACTION_DATE = ss.TRANSACTION_DATE 
		AND st.SAVING_SUMMARY_ID=ss.SAVING_SUMMARY_ID
	WHERE st.OFFICE_ID=6 AND st.ORGANIZATION_ID=4 AND ss.SAVING_STATUS = 1
	GROUP BY st.OFFICE_ID, st.CENTER_ID, 
		st.MEMBER_ID, st.PRODUCT_ID , st.TRANSACTION_DATE,
		st.SAVING_SUMMARY_ID,st.ORGANIZATION_ID,st.NO_OF_ACCOUNT;
	
	
	INSERT INTO DAILY_SAVING_TRX ( SAVING_SUMMARY_ID, ORGANIZATION_ID,OFFICE_ID, CENTER_ID,
	MEMBER_ID, PRODUCT_ID, BALANCE, TRANSACTION_DATE, NO_OF_ACCOUNT ) 
	SELECT DISTINCT ss.SAVING_SUMMARY_ID,ss.ORGANIZATION_ID,
	ss.OFFICE_ID, ss.CENTER_ID, ss.MEMBER_ID, 
		ss.PRODUCT_ID, (ss.DEPOSIT-ss.WITHDRAWAL) AS BALANCE, 
		TO_DATE('2019-10-01','YYYY-MM-DD') AS TRANSACTION_DATE, ss.NO_OF_ACCOUNT
	FROM SAVING_SUMMARY ss  
	LEFT JOIN DAILY_SAVING_TRX dst 
	ON (ss.PRODUCT_ID = dst.PRODUCT_ID) 
		AND (ss.MEMBER_ID = dst.MEMBER_ID) 
		AND (ss.CENTER_ID = dst.CENTER_ID) 
		AND (ss.OFFICE_ID = dst.OFFICE_ID)
		AND  ss.NO_OF_ACCOUNT = dst.NO_OF_ACCOUNT
		AND  ss.SAVING_SUMMARY_ID = dst.SAVING_SUMMARY_ID
	WHERE ss.OFFICE_ID = 6
	AND ss.ORGANIZATION_ID=4 AND dst.OFFICE_ID IS NULL
		AND dst.CENTER_ID Is Null 
		AND dst.MEMBER_ID Is Null 
		AND dst.PRODUCT_ID Is Null 
		AND ss.SAVING_STATUS = 1;
	
	startMonth := UTIL.GET_MONTH_FROM_DATE(vMonthStartDate);
	startYear := UTIL.GET_YEAR_FROM_DATE(vMonthStartDate);
	
	INSERT INTO DAILY_SAVING_COLLECTION (SAVING_SUMMARY_ID,OFFICE_ID,MEMBER_ID,PRODUCT_ID,
	CENTER_ID, NO_OF_ACCOUNT, TRANSACTION_DATE, DEPOSIT, WITHDRAWAL, BALANCE, INTEREST_RATE,
	SAVING_INSTALLMENT, CUM_INTEREST, MONTHLY_INTEREST, PENALTY, OPENING_DATE, MATURED_DATE,
	CLOSING_DATE,TRANS_TYPE,SAVING_STATUS,EMPLOYEE_ID,MEMBER_CATEGORY_ID,POSTED,ORGANIZATION_ID,
	IS_ACTIVE,INACTIVE_DATE,CREATE_USER,CREATE_DATE,CUR_DEPOSIT,CUR_WITHDRAWAL,CUR_INTEREST,
	CUR_PENALTY,DURATION,INSTALLMENT_NO,LATE_FEE,SAVING_ACCOUNT_NO)
	SELECT * 
	FROM  SAVING_SUMMARY s
	WHERE  (UTIL.GET_DAY_FROM_DATE(s.OPENING_DATE) > 7) 
	AND UTIL.GET_MONTH_FROM_DATE(s.OPENING_DATE) = startMonth 
	AND UTIL.GET_YEAR_FROM_DATE(s.OPENING_DATE) = startYear
	AND s.OFFICE_ID = 6 AND s.ORGANIZATION_ID=4
	AND s.SAVING_STATUS = 1;
	
	IF(cMon = 2) THEN
		IF(MOD(cYear , 4) = 0) THEN
			
			MONTH_END_PROCESS.UPDATE_DAILY_SAVING_TRX_BALANCE(
							monthEndDate, 22, officeID, orgID);
		END IF;
	
		IF(MOD(cYear , 4) <> 0) THEN
			
			MONTH_END_PROCESS.UPDATE_DAILY_SAVING_TRX_BALANCE(
							monthEndDate, 21, officeID, orgID);	
		END IF;
	END IF;

	IF(cMon = 1 OR cMon = 3 OR cMon = 5 OR cMon = 7 OR cMon = 8 OR cMon = 10 OR cMon = 12) THEN
		MONTH_END_PROCESS.UPDATE_DAILY_SAVING_TRX_BALANCE(
							monthEndDate, 24, officeID, orgID);
	END IF;

	IF(cMon = 4 OR cMon = 6 OR cMon = 9 OR cMon = 11) THEN 
		MONTH_END_PROCESS.UPDATE_DAILY_SAVING_TRX_BALANCE(
							monthEndDate, 23, officeID, orgID);
	END IF;

	If ((MOD(cYear, 4) = 0) OR (MOD(cYear, 400)=0) OR (MOD(cYear, 100)=0)) THEN
		totDay := 366*100;
	ELSE
		totDay := 365*100;
	END IF;
	
	intTotalDay := (UTIL.GET_DAY_DIFF(monthEndDate,vMonthStartDate)+1);

	INSERT INTO NEW_AC_IN_7 (SAVING_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID,CENTER_ID,MEMBER_ID,
	PRODUCT_ID, BALANCE, TRANSACTION_DATE,WITHDRAWAL,OP_DAY,OP_MONTH,OP_YEAR,NO_OF_ACCOUNT)
	SELECT st.SAVING_SUMMARY_ID, st.ORGANIZATION_ID,st.OFFICE_ID, st.CENTER_ID, st.MEMBER_ID, 
        st.PRODUCT_ID,  st.BALANCE, 
		st.TRANSACTION_DATE, ss.WITHDRAWAL,   
		UTIL.GET_DAY_FROM_DATE(ss.OPENING_DATE) as OP_DAY ,   
		UTIL.GET_MONTH_FROM_DATE(ss.OPENING_DATE) as OP_MONTH ,
		UTIL.GET_YEAR_FROM_DATE(ss.OPENING_DATE) as OP_YEAR, 
		st.NO_OF_ACCOUNT
	FROM SAVING_TRX st INNER JOIN SAVING_SUMMARY ss 
    ON (st.PRODUCT_ID = ss.PRODUCT_ID) 
	AND (st.MEMBER_ID = ss.MEMBER_ID) 
	AND (st.CENTER_ID = ss.CENTER_ID)  
	AND (st.OFFICE_ID = ss.OFFICE_ID) 
	AND st.NO_OF_ACCOUNT = ss.NO_OF_ACCOUNT 
	AND st.SAVING_SUMMARY_ID = ss.SAVING_SUMMARY_ID 
    Where st.OFFICE_ID = 6 AND st.ORGANIZATION_ID=4
		AND st.TRANSACTION_DATE = ss.OPENING_DATE 
		AND ss.WITHDRAWAL = 0 AND UTIL.GET_DAY_FROM_DATE(ss.OPENING_DATE) >= 1 
		AND UTIL.GET_DAY_FROM_DATE(ss.OPENING_DATE)  <= 7 
		AND UTIL.GET_MONTH_FROM_DATE(ss.OPENING_DATE) = 10
		AND UTIL.GET_YEAR_FROM_DATE(ss.OPENING_DATE) = 2019
		AND ss.SAVING_STATUS = 1;
		
	MERGE INTO DAILY_SAVING_TRX t
	USING (
		SELECT n.BALANCE,n.TRANSACTION_DATE,
		dst.OFFICE_ID,dst.PRODUCT_ID,dst.MEMBER_ID,dst.CENTER_ID,dst.NO_OF_ACCOUNT
		FROM  DAILY_SAVING_TRX dst INNER JOIN NEW_AC_IN_7 n  
		 ON (dst.PRODUCT_ID = n.PRODUCT_ID) 
					AND (dst.MEMBER_ID = n.MEMBER_ID) 
					AND (dst.CENTER_ID = n.CENTER_ID)  
					AND (dst.OFFICE_ID = n.OFFICE_ID) 
					AND dst.NO_OF_ACCOUNT = n.NO_OF_ACCOUNT 
					AND DST.SAVING_SUMMARY_ID = n.SAVING_SUMMARY_ID  
	WHERE dst.OFFICE_ID = 6) s
	ON (t.OFFICE_ID = s.OFFICE_ID AND t.PRODUCT_ID = s.PRODUCT_ID AND 
	t.MEMBER_ID = s.MEMBER_ID AND t.CENTER_ID = s.MEMBER_ID AND 
	t.NO_OF_ACCOUNT = s.NO_OF_ACCOUNT)
	WHEN MATCHED THEN
		UPDATE SET t.BALANCE = s.BALANCE, t.TRANSACTION_DATE = s.TRANSACTION_DATE;
	
		

	DELETE FROM MONTH_WISE_SAVING_INTEREST 
		WHERE OFFICE_ID = 6 AND UTIL.GET_MONTH_FROM_DATE(TRANSACTION_DATE)=cMon 
		AND UTIL.GET_YEAR_FROM_DATE(TRANSACTION_DATE)=cYear AND ORGANIZATION_ID=4;
	
	INSERT INTO MONTH_WISE_SAVING_INTEREST(ORGANIZATION_ID,OFFICE_ID, CENTER_ID, MEMBER_ID,
	PRODUCT_ID,BALANCE,INTEREST,TRANSACTION_DATE,NO_OF_ACCOUNT,SAVING_SUMMARY_ID)
	SELECT dst.ORGANIZATION_ID,dst.OFFICE_ID,dst.CENTER_ID,
		dst.MEMBER_ID,dst.PRODUCT_ID,dst.BALANCE,
		(dst.BALANCE*ss.INTEREST_RATE*intTotalDay)/totDay as INTEREST,monthEndDate as TRANSACTION_DATE
		, dst.NO_OF_ACCOUNT,dst.SAVING_SUMMARY_ID
	FROM SAVING_SUMMARY ss 
	INNER JOIN DAILY_SAVING_TRX dst 
	On (ss.MEMBER_ID = dst.MEMBER_ID) 
		AND (ss.CENTER_ID = dst.CENTER_ID)  
		AND (ss.OFFICE_ID = dst.OFFICE_ID) 
		AND (ss.PRODUCT_ID = dst.PRODUCT_ID) 
		AND ss.NO_OF_ACCOUNT = dst.NO_OF_ACCOUNT
		AND ss.SAVING_SUMMARY_ID = dst.SAVING_SUMMARY_ID  
	WHERE ss.SAVING_STATUS = 1 AND ss.OFFICE_ID = 6;


	MERGE INTO MONTH_WISE_SAVING_INTEREST t
	USING ( SELECT m.INTEREST, m.MONTH_WISE_SAVING_INTERST_ID
	FROM MONTH_WISE_SAVING_INTEREST m 
	INNER JOIN DAILY_SAVING_COLLECTION d 
	On d.OFFICE_ID = m.OFFICE_ID 
		AND d.CENTER_ID = m.CENTER_ID 
		AND d.MEMBER_ID = m.MEMBER_ID 
		AND d.PRODUCT_ID = m.PRODUCT_ID 
		AND d.NO_OF_ACCOUNT = m.NO_OF_ACCOUNT 
		AND d.SAVING_SUMMARY_ID = m.SAVING_SUMMARY_ID 
	WHERE  m.OFFICE_ID = 6) s
	ON (t.MONTH_WISE_SAVING_INTERST_ID = s.MONTH_WISE_SAVING_INTERST_ID)
	WHEN MATCHED THEN
	UPDATE SET INTEREST = 0;

	DELETE FROM DAILY_LOAN_TRX WHERE OFFICE_ID=6 AND ORGANIZATION_ID=4;

	DELETE FROM DAILY_SAVING_TRX WHERE OFFICE_ID=6 AND ORGANIZATION_ID=4;

	UPDATE PROCESS_INFO 
		SET MONTH_CLOSING_STATUS=1, MONTH_CLOSING_DATE=monthEndDate
		WHERE  OFFICE_ID = 6 AND BUSINESS_DATE=monthEndDate;
	
	DELETE FROM NEW_AC_IN_7 WHERE OFFICE_ID = 6;
	DELETE FROM SAVING_TRANSACTION WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_SAVINGS_REGISTER WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_MONTHLY_PROCESS_1 WHERE OFFICE_ID = 6;
	DELETE FROM TEMP_MONTHLY_PROCESS_2 WHERE OFFICE_ID = 6;
	DELETE FROM DAILY_SAVING_COLLECTION WHERE OFFICE_ID = 6;



	MERGE INTO LOAN_SUMMARY t
	USING (SELECT ul.LOAN_SUMMARY_ID,ul.OFFICE_ID,ul.CENTER_ID,ul.MEMBER_ID,ul.PRODUCT_ID,ul.LOAN_TERM,
	ul.LOAN_INSTALLMENT,ul.INT_INSTALLMENT,
	(CASE WHEN p.INTEREST_CALCULATION_METHOD='F' THEN ul.INT_CHARGE
		WHEN p.INTEREST_CALCULATION_METHOD IN ('A','E','R') THEN
		ul.INT_CHARGE   + (ul.PRINCIPAL_LOAN - ul.LOAN_REPAID) * 
		(case when ul.INSTALLMENT_NO>=ul.DURATION then ((ul.INTEREST_RATE/100)*UTIL.GET_DAY_DIFF(TO_DATE('2019-10-31','YYYY-MM-DD'),ul.INSTALLMENT_DATE))/365 else (ul.INTEREST_RATE/100)/ul.DURATION end)
		WHEN p.INTEREST_CALCULATION_METHOD='D' THEN 
			ul.INT_CHARGE+(ul.PRINCIPAL_LOAN-ul.LOAN_REPAID)*ul.INTEREST_RATE* UTIL.GET_DAY_DIFF(TO_DATE('2019-10-31','YYYY-MM-DD'),ul.INSTALLMENT_DATE) /36500 
	END) CURRENT_CHARGE,
	TO_DATE('2019-10-31','YYYY-MM-DD') INSTALLMENT_DATE,
						ul.INSTALLMENT_NO+1 WEEK_PASSED
	 FROM LOAN_SUMMARY ul 
	INNER JOIN PRODUCTS p ON ul.PRODUCT_ID=p.PRODUCT_ID
	WHERE ul.OFFICE_ID=6 AND ul.LOAN_STATUS=1
	AND ul.DISBURSE_DATE < TO_DATE('2019-10-01','YYYY-MM-DD') --And ul.WeekPassed<ul.Duration
	AND p.PAYMENT_FREQUENCY='M'
	AND ul.LOAN_SUMMARY_ID NOT IN
		(
		SELECT LOAN_SUMMARY_ID
		FROM LOAN_TRX ul 
		WHERE ul.OFFICE_ID=6 
		AND ul.INSTALLMENT_DATE BETWEEN TO_DATE('2019-10-01','YYYY-MM-DD') 
				AND TO_DATE('2019-10-31','YYYY-MM-DD')
		)
	) s
	ON(t.OFFICE_ID = s.OFFICE_ID AND t.CENTER_ID = s.CENTER_ID AND t.MEMBER_ID = s.MEMBER_ID AND
	t.PRODUCT_ID = s.PRODUCT_ID AND t.LOAN_TERM = s.LOAN_TERM AND t.LOAN_SUMMARY_ID = s.LOAN_SUMMARY_ID 
	AND t.INSTALLMENT_START_DATE <= TO_DATE('2019-10-31','YYYY-MM-DD'))
	WHEN MATCHED THEN
	UPDATE SET t.INSTALLMENT_NO=s.WEEK_PASSED,
		t.INT_CHARGE=s.CURRENT_CHARGE;

	INSERT INTO LOAN_TRX ( LOAN_SUMMARY_ID,ORGANIZATION_ID,OFFICE_ID, CENTER_ID, 
	MEMBER_ID, PRODUCT_ID, LOAN_TERM,  LOAN_PAID, LOAN_DUE, INT_DUE, INT_CHARGE, INT_PAID, 
	INSTALLMENT_DATE,TRX_TYPE,INSTALLMENT_NO, EMPLOYEE_ID,INVESTOR_ID,TRX_DATE,MEMBER_CATEGORY_ID) 
	SELECT ul.LOAN_SUMMARY_ID,ul.ORGANIZATION_ID,ul.OFFICE_ID,ul.CENTER_ID,ul.MEMBER_ID,
	ul.PRODUCT_ID,ul.LOAN_TERM, 0 LOAN_PAID,ul.LOAN_INSTALLMENT LOAN_DUE,ul.INT_INSTALLMENT INT_DUE,
	(CASE WHEN p.INTEREST_CALCULATION_METHOD='F' THEN 0
	WHEN p.INTEREST_CALCULATION_METHOD IN('A','E','R') THEN  (ul.PRINCIPAL_LOAN - ul.LOAN_REPAID) * 
		(CASE WHEN ul.INSTALLMENT_NO>=ul.DURATION THEN 
			((ul.INTEREST_RATE/100)*UTIL.GET_DAY_DIFF(TO_DATE('2019-10-31','YYYY-MM-DD'),ul.INSTALLMENT_DATE))/365 
				ELSE (ul.INTEREST_RATE/100)/ul.DURATION END)
	WHEN p.INTEREST_CALCULATION_METHOD='D' THEN (ul.PRINCIPAL_LOAN-ul.LOAN_REPAID)*ul.INTEREST_RATE* UTIL.GET_DAY_DIFF(TO_DATE('2019-10-31','YYYY-MM-DD'),ul.INSTALLMENT_DATE) /36500 
	END) INT_CHARGE,0 INT_PAID,TO_DATE('2019-10-31','YYYY-MM-DD') INSTALLMENT_DATE,10 TRX_TYPE,ul.INSTALLMENT_NO WEEK_PASSED,
	ul.EMPLOYEE_ID,ul.INVESTOR_ID,TO_DATE('2019-10-31','YYYY-MM-DD') TRX_DATE,ul.MEMBER_CATEGORY_ID
 	FROM LOAN_SUMMARY ul 
 	INNER JOIN PRODUCTS p ON ul.PRODUCT_ID=p.PRODUCT_ID
	WHERE ul.OFFICE_ID=6 AND ul.LOAN_STATUS=1
	AND ul.DISBURSE_DATE<TO_DATE('2019-10-01','YYYY-MM-DD') 
	AND p.PAYMENT_FREQUENCY='M'
	AND ul.INSTALLMENT_START_DATE<= TO_DATE('2019-10-31','YYYY-MM-DD') 
	AND ul.LOAN_SUMMARY_ID
	NOT IN
	(
	SELECT LOAN_SUMMARY_ID
	FROM LOAN_TRX ul 
	WHERE ul.OFFICE_ID=6 AND ul.INSTALLMENT_DATE BETWEEN TO_DATE('2019-10-01','YYYY-MM-DD') AND TO_DATE('2019-10-31','YYYY-MM-DD')
	);


	MERGE INTO LOAN_TRX t
	USING (
	SELECT ul.LOAN_SUMMARY_ID, ul.OFFICE_ID,ul.CENTER_ID,ul.PRODUCT_ID,ul.MEMBER_ID,ul.LOAN_TERM
	FROM LOAN_TRX lr INNER JOIN LOAN_SUMMARY ul on ul.OFFICE_ID=lr.OFFICE_ID
	AND ul.CENTER_ID=lr.CENTER_ID AND ul.MEMBER_ID=lr.MEMBER_ID
	AND ul.PRODUCT_ID=lr.PRODUCT_ID AND ul.LOAN_TERM=lr.LOAN_TERM
	AND ul.LOAN_SUMMARY_ID=lr.LOAN_SUMMARY_ID
	INNER JOIN PRODUCTS p ON ul.PRODUCT_ID=p.PRODUCT_ID
	WHERE ul.OFFICE_ID=6
	AND p.PAYMENT_FREQUENCY='M' AND ul.INSTALLMENT_NO>ul.DURATION
	AND lr.INSTALLMENT_DATE=TO_DATE('2019-10-31','YYYY-MM-DD')
	) s
	ON (t.OFFICE_ID = s.OFFICE_ID AND t.CENTER_ID = s.CENTER_ID 
	AND t.PRODUCT_ID = s.PRODUCT_ID AND
	t.MEMBER_ID = s.MEMBER_ID AND t.LOAN_TERM = s.LOAN_TERM 
	AND t.LOAN_SUMMARY_ID = s.LOAN_SUMMARY_ID AND
	t.INSTALLMENT_DATE = TO_DATE('2019-10-31','YYYY-MM-Dd'))
	WHEN MATCHED THEN
	UPDATE SET t.LOAN_DUE=0,
	t.INT_DUE=0;



	MERGE INTO LOAN_SUMMARY t
	USING (
	SELECT ul.LOAN_SUMMARY_ID, ul.OFFICE_ID,ul.CENTER_ID,ul.PRODUCT_ID,
	ul.MEMBER_ID,ul.LOAN_TERM,lr.INSTALLMENT_DATE
	FROM LOAN_TRX lr INNER JOIN LOAN_SUMMARY ul ON ul.OFFICE_ID=lr.OFFICE_ID
	AND ul.CENTER_ID=lr.CENTER_ID AND ul.MEMBER_ID=lr.MEMBER_ID
	AND ul.PRODUCT_ID=lr.PRODUCT_ID AND ul.LOAN_TERM=lr.LOAN_TERM
	INNER JOIN PRODUCTS p ON ul.PRODUCT_ID=p.PRODUCT_ID
	WHERE ul.OFFICE_ID=6
	AND p.PAYMENT_FREQUENCY='M'
	AND lr.INSTALLMENT_DATE=TO_DATE('2019-10-31','YYYY-MM-DD')
	AND ul.LOAN_STATUS=1
	) s
	ON (t.OFFICE_ID = s.OFFICE_ID AND t.CENTER_ID = s.CENTER_ID AND t.MEMBER_ID = s.MEMBER_ID AND
	t.PRODUCT_ID = s.PRODUCT_ID AND t.LOAN_TERM = s.LOAN_TERM AND t.LOAN_SUMMARY_ID = s.LOAN_SUMMARY_ID 
	AND t.INSTALLMENT_START_DATE <= TO_DATE('2019-10-31','YYYY-MM-DD')) 
	WHEN MATCHED THEN
	Update set t.INSTALLMENT_DATE=s.INSTALLMENT_DATE;

	
	MERGE INTO LOAN_TRX t
	USING (
	SELECT ul.LOAN_SUMMARY_ID, ul.OFFICE_ID,ul.CENTER_ID,ul.PRODUCT_ID,ul.MEMBER_ID,ul.LOAN_TERM
	FROM LOAN_TRX lr INNER JOIN LOAN_SUMMARY ul ON ul.LOAN_SUMMARY_ID=lr.LOAN_SUMMARY_ID
	AND ul.OFFICE_ID=lr.OFFICE_ID AND ul.CENTER_ID=lr.CENTER_ID
	AND ul.MEMBER_ID=lr.MEMBER_ID AND ul.PRODUCT_ID=lr.PRODUCT_ID AND ul.LOAN_TERM=lr.LOAN_TERM
	INNER JOIN PRODUCTS p ON ul.PRODUCT_ID=p.PRODUCT_ID
	INNER JOIN EXPIRE_INFOS ex ON ul.OFFICE_ID=ex.OFFICE_ID
	AND ul.CENTER_ID=ex.CENTER_ID
	AND ul.MEMBER_ID=ex.MEMBER_ID
	Where ul.OFFICE_ID=6
	AND p.PAYMENT_FREQUENCY='M' AND ex.EXPIRE_DATE>ul.DISBURSE_DATE 
	AND ul.LOAN_STATUS=1 and ul.IS_ACTIVE=1 
	AND lr.INSTALLMENT_DATE=TO_DATE('2019-10-31','YYYY-MM-DD')
	) s 
	ON (t.LOAN_SUMMARY_ID = s.LOAN_SUMMARY_ID AND t.OFFICE_ID = s.OFFICE_ID AND t.CENTER_ID = s.CENTER_ID
	AND t.MEMBER_ID = s.MEMBER_ID AND t.PRODUCT_ID = s.PRODUCT_ID AND t.LOAN_TERM = s.LOAN_TERM
	AND t.INSTALLMENT_DATE = TO_DATE('2019-10-31','YYYY-MM-DD'))
	WHEN MATCHED THEN
	UPDATE SET t.LOAN_DUE=0,t.INT_DUE=0;
	

	<<validation_point>>
    BEGIN
	  IF(isValid = 1) THEN
    	WRITE_LOG(msg);
    	ROLLBACK;
	  END IF;
    END;
   
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	ROLLBACK;

COMMIT;

END;