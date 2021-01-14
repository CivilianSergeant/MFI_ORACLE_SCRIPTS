CREATE OR REPLACE PROCEDURE MFIDSK.DAY_END(
	officeID IN NUMBER,
	businessDate IN DATE,
	orgID IN NUMBER,
	createUser IN VARCHAR
)
IS
	countRecord NUMBER(32) := 0;
	msg VARCHAR2(255) := '';
	isValid NUMBER(1) := 0;
	spName varchar(80) := SYSDATE || ' DAILY_END: ';
BEGIN
	
	 SELECT COUNT(*) INTO countRecord FROM(SELECT COUNT(SAVING_SUMMARY_ID) FROM DAILY_SAVING_TRX d 
	 INNER JOIN MEMBERS m ON d.MEMBER_ID=m.MEMBER_ID
	 WHERE d.OFFICE_ID=6 AND m.MEMBER_STATUS=2
	 GROUP BY SAVING_SUMMARY_ID
	 Having sum(d.SAVING_INSTALLMENT)+sum(d.WITHDRAWAL)+sum(PENALTY)+sum(MONTHLY_INTEREST) <> 0);
	
	 IF(countRecord>0) THEN
		msg := spNAME || 'Saving amount Collected from drop Member ......Pls check savings Amount: Office:' || officeID;
		isValid := 1;
   		GOTO validation_point;
	 END IF;
	
	 -- Lot of checks will be here
	 
	 -- Adjust procedure
	 	DAY_END_PROCESS.ADJUSTMENT(officeID,orgID,createUser);
	 
	 -- Insert Data Into LoanTrx Table from Daily Transaction
	 	DAY_END_PROCESS.ADD_LOAN_TRX(officeID, businessDate);
	 	
	 	DAY_END_PROCESS.UPDATE_LOAN_SUMMARY(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.UPDATE_LOAN_CORRECTION(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.INSERT_REGULAR_DISBURSEMENT(officeID, orgID, businessDate);
	 	
	 	DAY_END_PROCESS.UPDATE_REGULAR_DISBURSEMENT_DATE(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.ADD_SAVING_TRX(officeID, orgID);
	 
	 	DAY_END_PROCESS.UPDATE_SAVING_SUMMARY_BALANCE(officeID,orgID);
	 
	 	DAY_END_PROCESS.UPDATE_LOAN_STATUS(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.UPDATE_LOAN_TRX_DUE(officeID,orgID, businessDate);
	 
	 	DAY_END_PROCESS.ADD_LOAN_TRX_DUE(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.UPDATE_CENTER_COLLECTION_DATE(officeID, businessDate);
	 
	 	-- Account Day Close
	 	ACCOUNTS.ACCOUNT_DAY_CLOSE(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.UPDATE_PROCESS_INFO(officeID, orgID, businessDate);
	 
	 	--01.03
	 	DAY_END_PROCESS.UPDATE_SAVING_SUMMARY_01_03(officeID, orgID, businessDate);
	 
	 	--01.01
	 	DAY_END_PROCESS.UPDATE_SAVING_SUMMARY_01_01(officeID, businessDate);
	 
	 	--01.02
	 	DAY_END_PROCESS.UPDATE_SAVING_SUMMARY_01_02(officeID, orgID, businessDate);
	 
	 	-- Drop 01.03--
	 	DAY_END_PROCESS.UPDATE_SAVING_DROP_01_03(officeID, orgID, businessDate);
	 
	 	-- DROP MEMBER 01.04
	 	DAY_END_PROCESS.UPDATE_MEMBER_DROP_01_04(officeID, orgID, businessDate);
	 
	 	DAY_END_PROCESS.UPDATE_COLLECTION_SAVING_SUMMARY(officeID);
	 
	 	DAY_END_PROCESS.UPDATE_LOAN_SUMMARY_CHARGE_DUE_PAID_AMOUNT(officeID, businessDate);
	
		
	
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