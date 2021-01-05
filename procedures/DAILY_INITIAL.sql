CREATE OR REPLACE PROCEDURE MFIDSK.DAILY_INITIAL
(
   officeID IN NUMBER,
   businessDate IN DATE,
   createUser IN VARCHAR,
   createDate IN VARCHAR,
   orgID IN NUMBER
)
AS
/**
 * Daily Initial Procedure
 * Re-write in PL/SQL By: Himel
 */
	closingStatus Number(1) :=0;
	lastTrxDate DATE := NULL;
	startBusinessDate DATE := NULL;
	monthClosingDate DATE := NULL;
	monthClosingStatus NUMBER(1) :=0;
	weekDay VARCHAR(10) := '';
	msg VARCHAR2(255) := '';
	isError NUMBER(1) := 0;
	isValid NUMBER(1) := 0;
	isValidDate NUMBER(1) := 0;
	lastDayEndDate DATE := NULL;
	maxHolidayDate DATE := NULL;
	officeCode varchar(5) := '';
	innDiff NUMBER(10) := 0;
	lastProcessInfoID NUMBER(32) :=0;
	spName varchar(80) := SYSDATE || ' DAILY_INITIAL: ';
BEGIN
   -- Setting up initial values
	startBusinessDate := businessDate;
	weekDay := GET_WEEK_DAY(startBusinessDate);
	
	-- Step 1: Check is daily initial date valid or not
   BEGIN
	   
	  SELECT MAX(BUSINESS_DATE) INTO lastDayEndDate FROM PROCESS_INFO 
	  	WHERE OFFICE_ID=officeID AND CLOSING_STATUS=1 
	  	AND BUSINESS_DATE<startBusinessDate;
       
	  SELECT COUNT( DISTINCT BUSINESS_DATE) INTO innDiff FROM HOLIDAYS 
	  	WHERE OFFICE_ID=officeID ---and year(BUSINESS_DATE)=@year and MONTH(BUSINESS_DATE)=@mon 
		AND (BUSINESS_DATE>=lastDayEndDate) AND BUSINESS_DATE<=startBusinessDate;
				
		IF((UTIL.GET_DAY_DIFF(startBusinessDate,lastDayEndDate)-innDiff)>1) THEN
			msg := spNAME || ' Invalid Date selected ' || startBusinessDate;
			isValid := 1;
	   		GOTO validation_point;
		END IF;
	
   EXCEPTION
   	WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
   END;
  
   -- Step 2: Check is daily initial process already done
   BEGIN	
		SELECT count(*) INTO isValidDate FROM PROCESS_INFO 
			WHERE OFFICE_ID=officeID AND BUSINESS_DATE = startBusinessDate 
			AND CLOSING_STATUS = 1;
		
		IF(isValidDate>0) THEN
	   		msg := spName || 'Start work process already done for ' || businessDate;
	   		isValid := 1;
	   		GOTO validation_point;
		   
		 END IF;
	EXCEPTION
   	WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
   END; 
  
   -- Step 3: Check is daily initial process already started
   BEGIN 
	   SELECT count(*) INTO isValidDate FROM PROCESS_INFO 
	   	WHERE OFFICE_ID=officeID and CLOSING_DATE IS NULL;
	   
	   IF(isValidDate>0) THEN
			msg := spName || 'Start work Process already running ' || businessDate;
			isValid := 1;
			GOTO validation_point;	
		   
	   END IF;
	  
	EXCEPTION
   		WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
   END;
  
   -- Step 4: Check that is the daily initial process trying to start on previous date
	BEGIN
		SELECT max(CLOSING_DATE) INTO lastDayEndDate FROM PROCESS_INFO 
		WHERE OFFICE_ID=officeID AND CLOSING_STATUS =1 And ORGANIZATION_ID=orgID;

			IF (startBusinessDate <=lastDayEndDate) THEN
				msg := spName || 'Sorry! Can not start work on previous date ' || startBusinessDate;
				isValid := 1;
				GOTO validation_point;	
			END IF;
		
	  EXCEPTION
   		WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
	END;

   -- Step 5: Check Last Day Closing
   BEGIN
	   	SELECT NVL(MAX(Business_Date),startBusinessDate), CLOSING_STATUS INTO lastTrxDate,closingStatus  
	   		FROM PROCESS_INFO WHERE OFFICE_ID=officeID 
	   			AND (INITIAL_DATE<startBusinessDate) 
	   			AND ORGANIZATION_ID=orgID GROUP BY CLOSING_STATUS;
	   	
	   	--SELECT CLOSING_STATUS INTO closingStatus FROM PROCESS_INFO WHERE OFFICE_ID=officeID AND INITIAL_DATE=lastTrxDate AND ORGANIZATION_ID=orgID;
	    
	    IF(startBusinessDate<>lastTrxDate) THEN
		    BEGIN
			    IF(closingStatus = 0) THEN 
					msg := spName || ' Day is not closing for ' || lastTrxDate;
					isValid := 1;
					GOTO validation_point;
			  	END IF;
		  	END;
	  	END IF;
	  
	  EXCEPTION
   		WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
   	END;
   
   -- Step 6: Check is the business day a holiday
   BEGIN
	   	SELECT COUNT(*) INTO isValidDate FROM HOLIDAYS 
   			WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID 
   			AND BUSINESS_DATE=startBusinessDate  
   			AND (HOLIDAY_TYPE='Weekly' OR HOLIDAY_TYPE='Govt');
		
   		IF(isValidDate>0) THEN
		 	msg := spName || 'Sorry! Today is Holiday Today ' || startBusinessDate;
			isValid := 1;
			GOTO validation_point;
		END IF;
	
		SELECT MAX(BUSINESS_DATE) INTO maxHolidayDate FROM HOLIDAYS 
			WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID 
			AND  BUSINESS_DATE<=startBusinessDate AND IS_ACTIVE=1;
		
		IF (maxHolidayDate>lastTrxDate) THEN
			lastTrxDate := maxHolidayDate;
		END IF;
	
		SELECT SUBSTR(OFFICE_CODE,0,3) INTO officeCode From OFFICES WHERE OFFICE_ID=officeID;
		IF (officeCode<>'999') THEN --Rais (2018-05-10)
			IF(UTIL.GET_DAY_DIFF(startBusinessDate,lastTrxDate)>1) THEN
				msg := spName || ' Invalid transaction date: ' || startBusinessDate;
				isValid := 1;
				GOTO validation_point;
			END IF;
		END	IF;	
	
	EXCEPTION
   		WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
   END;
    
    -- Step 7: Check Last Month Closing
    BEGIN
	   SELECT TO_DATE(max(Month_Closing_Date),'DD-MM-YY') INTO monthClosingDate from Process_Info where OFFICE_ID=officeID and MONTH_CLOSING_STATUS=1;
	   
	   IF(UTIL.GET_MONTH_DIFF(monthClosingDate,startBusinessDate) <> 1) THEN
			BEGIN
				msg := 'Month closing of last month (' || monthClosingDate || ') is not completed';
			    isValid := 1;
				GOTO validation_point;
			END;
		END IF;
	
 	EXCEPTION
		WHEN OTHERS THEN
   		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
    END;
   
   	BEGIN
	   	-- Step 8: Remove Records from DAILY_SAVING_TRX by office and organization
		DELETE FROM DAILY_SAVING_TRX WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID;
	
		-- Step 9: Insert Weekly Saving Transactions 
	   	WRITE_LOG('START WEEKLY SAVING TRX FROM OFFICE: ' || officeID);
		DAILY_START_PROCESS.ADD_WEEKLY_SAVING_TRX(startBusinessDate,createUser,weekDay,officeID,orgID); 
	
		-- Step 10: Remove Records from DAILY_LOAN_TRX by office and organization
		DELETE FROM DAILY_LOAN_TRX	WHERE OFFICE_ID=officeID And ORGANIZATION_ID=orgID;
	
		-- Step 11: ADD DAILY LOAN TRX RECORDS
		WRITE_LOG('START ADD_WEEKLY_LOAN_TRX OFFICE: ' || officeID);
		DAILY_START_PROCESS.ADD_WEEKLY_LOAN_TRX(createDate,createUser,weekDay,officeID,orgID); 

		-- Step 12: ADD MONTHLY LOAN TRX RECORDS
		WRITE_LOG('START ADD_MONTHLY_LOAN_TRX OFFICE: ' || officeID);
		DAILY_START_PROCESS.ADD_MONTHLY_LOAN_TRX(createDate,createUser,weekDay,officeID,orgID); 
	
	    /** Step 13:
	     * Update loan paid if (installment+1) == duration then 
	     * set principal balance otherwise as it is
	     */
		DAILY_START_PROCESS.UPDATE_LOAN_PAID(officeID);
		
		/** Step 14:
		 * IF Installment No greater or equal to loan duration
		 * then Update loan due, int due, loan paid,int paid to 0
		 */ 
		DAILY_START_PROCESS.RESET_LOAN_INT_PAID_DUE(officeID, orgID);
	
		
		-- Step 15: Delete Record for Holidays
		DAILY_START_PROCESS.DELETE_HOLIDAY_RECORDS(officeID,orgID,startBusinessDate);
		
		-- Step 16: Expire List
 		DAILY_START_PROCESS.DELETE_EXPIRE_LOAN_ACCOUNTS(officeID);
 	
		-- Step 17: Family Grace
		DAILY_START_PROCESS.DELETE_EXPIRED_FAMILY_GRACE_ACCOUNTS(officeID,startBusinessDate);
	
		 -- Step 18: MAKE LOAN ACCOUNT PENDING WHILE DISBURSE DATE IS EQUAL TO startBusinessDate
		 UPDATE LOAN_SUMMARY SET DISBURSE_DATE = NULL,
				INT_CHARGE=0, INSTALLMENT_START_DATE=NULL, IS_APPROVED=0
		 WHERE OFFICE_ID=officeID And DISBURSE_DATE=startBusinessDate AND ORGANIZATION_ID=orgID;
	
		-- Step 19: Delete Voucher
		ACCOUNTS.UPDATE_AUTO_VOUCHER(officeID);
		
		-- Step 20: Update Daily Loan Trx For Lift Loan
		DAILY_START_PROCESS.UPDATE_LOAN_FOR_LIFT_LOAN(officeID, startBusinessDate);
	
		-- Step 21: Update Daily Loan Trx For Duration Over Charge
		IF(orgID = 5) THEN
			DAILY_START_PROCESS.UPDATE_LOAN_FOR_JCF(officeID, orgID, startBusinessDate);
		END IF;
		
		DAILY_START_PROCESS.UPDATE_LOAN_FOR_LAST_INSTALLMENT(officeID, orgID, startBusinessDate);
	
		-- Step 22: Insert LTS Saving Transactions 
		WRITE_LOG('START LTS SAVING TRX FROM OFFICE: ' || officeID);
		DAILY_START_PROCESS.ADD_LTS_SAVING_TRX(createDate,createUser,weekDay,officeID,orgID);

		-- Step 23: UPDATE LOAN SUMMARY TO RESET PARTIAL AMOUNT AND DELETE TEMP DATA
		DAILY_START_PROCESS.RESET_PARTIAL_AMOUNT(officeID, orgID);
	
		DAILY_START_PROCESS.DELETE_TEMP_DATA(officeID,startBusinessDate);
	
		-- Insert Process Info record for given date if not exist
		SELECT COUNT(PROCESS_INFO_ID) INTO lastProcessInfoID FROM PROCESS_INFO 
			WHERE OFFICE_ID=officeID AND BUSINESS_DATE = startBusinessDate;
		
		IF(lastProcessInfoID = 0) THEN
			INSERT INTO PROCESS_INFO (OFFICE_ID,BUSINESS_DATE,CLOSING_STATUS,MONTH_CLOSING_STATUS,
				INITIAL_DATE,INITIAL_STATUS,ORGANIZATION_ID,INITIAL_PROCESS_COUNT,IS_ACTIVE,CREATE_USER)
				VALUES(officeID,startBusinessDate,0,0,
				startBusinessDate,0,orgID,1,1,createUser);
		END IF;
	
	
	EXCEPTION
		WHEN OTHERS THEN
		msg := SQLERRM;
   	    isValid := 1;
   		GOTO validation_point;
	END;

    <<validation_point>>
    BEGIN
	  IF(isValid = 1) THEN
    	WRITE_LOG(msg);
    	ROLLBACK;
	  END IF;
    END;
   
EXCEPTION
	WHEN OTHERS THEN
	ROLLBACK;

COMMIT;
END;
/**
 * CALL DAILY_INITIAL(6,'2019-11-03','Himel','2019-11-03',4);
 * Daily Initial Procedure End
 */