CREATE OR REPLACE PROCEDURE MFIDSK.DAY_END(
	officeID IN NUMBER,
	businessDate IN DATE,
	orgID IN NUMBER,
	createUser IN VARCHAR
)
/**
 * Author: Himel
 * Day end process
 */
IS
	countRecord NUMBER(32) := 0;
	msg VARCHAR2(255) := '';
	isValid NUMBER(1) := 0;
	spName varchar(80) := SYSDATE || ' DAILY_END: ';
	tempDebitSum NUMBER(18,0);
	tempCreditSum NUMBER(18,0);
	vClosingStatus NUMBER(1);
	lastDayEndDate DATE;
BEGIN
	
	 -- Lot of checks will be here
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
	
	 SELECT COUNT(*) INTO countRecord FROM (SELECT dlt.OFFICE_ID,dlt.MEMBER_ID,dlt.CENTER_ID,
	 SUM(dlt.LOAN_PAID) LOAN_PAID,SUM(dlt.INT_PAID) INT_PAID 
	 FROM DAILY_LOAN_TRX dlt 
		WHERE dlt.TRX_DATE=businessDate 
			AND dlt.OFFICE_ID=officeID 
			GROUP BY dlt.OFFICE_ID,dlt.MEMBER_ID,dlt.CENTER_ID 
			HAVING (SUM(dlt.LOAN_PAID)<>0 OR SUM(dlt.INT_PAID)<>0)
	 UNION ALL
	 SELECT dst.OFFICE_ID,dst.MEMBER_ID,dst.CENTER_ID, 
	 SUM(dst.SAVING_INSTALLMENT) SAVING_INSTALLMENT, 
	 SUM(dst.WITHDRAWAL) WITHDRAWAL 
	 FROM DAILY_SAVING_TRX dst
		WHERE dst.TRANSACTION_DATE = businessDate 
		AND dst.OFFICE_ID=officeID 
		GROUP BY dst.OFFICE_ID,dst.MEMBER_ID,dst.CENTER_ID 
		HAVING (SUM(dst.SAVING_INSTALLMENT)<>0 OR SUM(dst.WITHDRAWAL)<>0)
	 UNION ALL
	 SELECT ls.OFFICE_ID,ls.MEMBER_ID,ls.CENTER_ID, 
	 SUM(ls.PRINCIPAL_LOAN) PRINCIPAL_LOAN, 0 WITHDRAWAL 
	 FROM LOAN_SUMMARY ls
	 WHERE ls.IS_ACTIVE=1 AND ls.DISBURSE_DATE = businessDate 
	 AND ls.OFFICE_ID=officeID
	 GROUP BY ls.OFFICE_ID,ls.MEMBER_ID,ls.CENTER_ID 
	 HAVING SUM(ls.PRINCIPAL_LOAN)<>0) r;
	
	 IF(countRecord <>0) THEN
	 	SELECT COUNT(*) INTO countRecord 
	 	FROM AUTO_VOUCHER_CHECK 
	 	WHERE OFFICE_ID=officeID AND CHECK_AUTO_VOUCHER=1;
	 	
	 	IF(countRecord =0) THEN
	 		msg := spNAME || 'Pls..run autovoucher process for Office:' || officeID;
			isValid := 1;
   			GOTO validation_point;
	 	END IF;
	 	
	 END IF;
	
	 SELECT SUM(NVL(atd.Debit,0)), SUM(NVL(atd.Credit,0)) 
	 	INTO tempDebitSum,tempCreditSum FROM ACC_TRX_MASTER atm 
	 	INNER JOIN ACC_TRX_DETAIL atd ON atm.TRX_MASTER_ID=atd.TRX_MASTER_ID 
		INNER JOIN ACC_CHART ac ON atd.ACC_ID=ac.ACC_ID
		WHERE atm.IS_ACTIVE=1 AND atd.IS_ACTIVE=1
		AND atm.TRX_DATE=businessDate AND atm.OFFICE_ID=officeID And atm.VOUCHER_TYPE IN ('Jr','Ba','Bc')
	GROUP BY atm.OFFICE_ID;
	
	IF (NVL(tempDebitSum,0)<>NVL(tempCreditSum,0)) THEN
	
		msg := spNAME ||' Sum Of Debit And Credit not equal '||businessDate;
		isValid := 1;
		GOTO validation_point;	
	END IF;	

	SELECT COUNT(*) INTO countRecord
	FROM ACC_TRX_MASTER atm 
	INNER JOIN ACC_TRX_DETAIL atd on atm.TRX_MASTER_ID=atd.TRX_MASTER_ID 
	INNER JOIN ACC_CHART ac on atd.ACC_ID=ac.ACC_ID
	WHERE atm.IS_ACTIVE=1 And atd.IS_ACTIVE=1
	 AND atm.OFFICE_ID=officeID AND atm.TRX_DATE=businessDate;
	
	IF (countRecord = 0) THEN
		msg:=spNAME || 'There is no data in DailyVoucher: ' || businessDate;
		isValid:=1;
		GOTO validation_point;
	END IF;

	SELECT NVL(CLOSING_STATUS,0) INTO vClosingStatus 
	FROM PROCESS_INFO WHERE OFFICE_ID=officeID 
	AND INITIAL_DATE=businessDate AND ORGANIZATION_ID=orgID;

	IF(vClosingStatus<>0) THEN
		msg:= spNAME || 'Day Initial is not completed for transaction date: ' || businessDate;
		isValid:=1;
		GOTO validation_point;
	END IF;

	Select NVL(MAX(INITIAL_DATE),businessDate) INTO lastDayEndDate 
	FROM PROCESS_INFO WHERE OFFICE_ID=officeID 
	AND INITIAL_DATE<businessDate AND ORGANIZATION_ID=orgID
	GROUP BY OFFICE_ID;

	SELECT NVL(CLOSING_STATUS,0) INTO vClosingStatus 
	FROM PROCESS_INFO WHERE OFFICE_ID=officeID 
	AND INITIAL_DATE = lastDayEndDate AND ORGANIZATION_ID=orgID;
	IF (vClosingStatus=0) THEN
		msg:='Day closing is not completed for transaction date: '|| lastDayEndDate;
		isValid:=1;
		GOTO validation_point;	
	END IF;
	
	 
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