CREATE OR REPLACE PACKAGE MFIDSK.ACCOUNTS
AS
   PROCEDURE UPDATE_AUTO_VOUCHER(officeID NUMBER);
   PROCEDURE ACCOUNT_DAY_CLOSE(officeID NUMBER, orgID NUMBER, businessDate DATE);
   PROCEDURE ACCOUNT_CLOSE(
   			office_id NUMBER,
			member_id NUMBER,
			center_id NUMBER,
			no_of_account NUMBER,
			saving_summary_id NUMBER,
			transaction_date DATE);
   PROCEDURE AUTO_ACCOUNT_CLOSE(officeID NUMBER,orgID NUMBER, businessDate DATE);
END ACCOUNTS;

CREATE OR REPLACE PACKAGE BODY MFIDSK.ACCOUNTS
AS
/**
 * Update Auto Voucher
 * Author Himel
 */
PROCEDURE UPDATE_AUTO_VOUCHER(officeID IN NUMBER) 
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [DELETE_VOUCHER]:';
hasAutoVoucher NUMBER(1) := 0;
BEGIN
	SELECT COUNT(*) INTO hasAutoVoucher FROM AUTO_VOUCHER_CHECK 
	WHERE OFFICE_ID=officeID and CHECK_AUTO_VOUCHER=1;
	
	IF(HASAUTOVOUCHER>0) THEN
		UPDATE AUTO_VOUCHER_CHECK
		SET CHECK_AUTO_VOUCHER=0 WHERE  OFFICE_ID=officeID;
	ELSE
		INSERT INTO AUTO_VOUCHER_CHECK(OFFICE_ID, CHECK_AUTO_VOUCHER)
		VALUES(officeID,0);
	END IF;

EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);

END;

/**
 * Account Day close
 * Author Himel
 */
PROCEDURE ACCOUNT_DAY_CLOSE(officeID NUMBER, orgID NUMBER, businessDate DATE)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName VARCHAR(80) := SYSDATE || ' [ACCOUNT_DAY_CLOSE]:';
yearStartDate DATE;
accCode VARCHAR(10):='';
accID NUMBER(19);
creditSum NUMBER(32);
debitSum NUMBER(32);
vYear NUMBER(4);
accMasTerId NUMBER(32);
accVoucherNO VARCHAR(50):='';
BEGIN
	
	DELETE FROM TMP_LEDGER WHERE OFFICE_ID=officeID;

	SELECT (YEAR_CLOSING_DATE+1),CASH_BOOK INTO yearStartDate,accCode FROM APPLICATION_SETTINGS
		WHERE OFFICE_ID=officeID AND ORGANIZATION_ID=orgID;

	SELECT ACC_ID INTO accID FROM ACC_CHART 
	WHERE ACC_CODE=accCode AND IS_ACTIVE=1 AND ORGANIZATION_ID=orgID;
	
	SELECT UTIL.GET_YEAR_FROM_DATE(businessDate) INTO vYear FROM DUAL;

	SELECT VOUCHER_NO INTO accVoucherNO FROM  ACC_LAST_VOUCHER WHERE OFFICE_ID=officeID;

	UPDATE ACC_LAST_VOUCHER
		SET		
		VOUCHER_NO=(SUBSTR(accVoucherNO,1,INSTR(accVoucherNO,'-')-1)|| '-' || vYear) 
		FROM ACC_LAST_VOUCHER 
		WHERE OFFICE_ID=officeID;

	INSERT INTO TMP_LEDGER(TRANSACTION_DATE, VOUCHER_NO, NARATION, 
			OFFICE_ID, ACC_ID, RECON_PURPOSE_CODE,
			REFERENCE, DEBIT, CREDIT, VOUCHER_TYPE)
		SELECT atm.TRX_DATE TRANSACTION_DATE,atm.VOUCHER_NO,atd.NARRATION NARATION,
		officeID OFFICE_ID,atd.ACC_ID, '' RECON_PURPOSE_CODE,
		'' REFERENCE,atd.DEBIT,atd.CREDIT,atm.VOUCHER_TYPE
		FROM ACC_TRX_MASTER atm 
		INNER JOIN ACC_TRX_DETAIL atd ON atm.TRX_MASTER_ID=atd.TRX_MASTER_ID 
		INNER JOIN ACC_CHART ac ON atd.ACC_ID=ac.ACC_ID
		WHERE atm.OFFICE_ID=officeID 
		AND atm.IS_ACTIVE=1 AND atm.TRX_DATE=businessDate
		AND atd.IS_ACTIVE=1;
	
		SELECT Sum(t.Debit),Sum(t.Credit) INTO creditSum,debitSum
		     FROM TMP_LEDGER t WHERE t.OFFICE_ID=officeID 
		     	AND t.VOUCHER_TYPE='CA' AND t.ACC_ID<>accID;
		    
		IF (debitSum)>0 THEN
		
			INSERT INTO ACC_TRX_MASTER(OFFICE_ID, TRX_DATE, VOUCHER_NO, VOUCHER_DESC,
			VOUCHER_TYPE, REFERENCE, 
			IS_POSTED, IS_ACTIVE,ORGANIZATION_ID)
			VALUES(officeID,businessDate,accVoucherNO,'N/A','Dr','N/A',
			0,1,orgID) 
			RETURNING TRX_MASTER_ID 
			INTO  accMasTerId;	
	
			
			INSERT INTO ACC_TRX_DETAIL(TRX_MASTER_ID, ACC_ID, DEBIT, NARRATION, IS_ACTIVE)
			--Values(@AccMasTerId,@accid,(@CreditSum-@DebitSum),'N/A',1)
			VALUES(accMasTerId,accID,(debitSum),'N/A',1); 
			
		END IF;

		IF (creditSum)>0 THEN
			INSERT INTO ACC_TRX_MASTER(OFFICE_ID, TRX_DATE, VOUCHER_NO, 
				VOUCHER_DESC, VOUCHER_TYPE, REFERENCE, IS_POSTED, IS_ACTIVE,ORGANIZATION_ID)
				Values(officeID,businessDate,accVoucherNO,'N/A','Cr','N/A',0,1,orgID)
				RETURNING TRX_MASTER_ID 
				INTO  accMasTerId;
				
			INSERT INTO ACC_TRX_DETAIL(TRX_MASTER_ID, ACC_ID, DEBIT, NARRATION, IS_ACTIVE)
				VALUES(accMasTerId,accID,(creditSum),'N/A',1);
		END IF;
		
	UPDATE ACC_TRX_MASTER
		SET IS_POSTED=1 WHERE OFFICE_ID=officeID AND TRX_DATE=businessDate;
	
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);
	
END;

PROCEDURE ACCOUNT_CLOSE(
   			office_id NUMBER,
			member_id NUMBER,
			center_id NUMBER,
			no_of_account NUMBER,
			saving_summary_id NUMBER,
			transaction_date DATE) 
IS
BEGIN
END;

PROCEDURE AUTO_ACCOUNT_CLOSE(officeID NUMBER,orgID NUMBER, businessDate DATE)
IS
	CURSOR cur IS
		SELECT s.OFFICE_ID,s.CENTER_ID,s.MEMBER_ID,s.PRODUCT_ID,s.NO_OF_ACCOUNT,
		s.SAVING_SUMMARY_ID,d.TRANSACTION_DATE
		FROM SAVING_SUMMARY s 
		INNER JOIN (SELECT dst.TRANSACTION_DATE,dst.SAVING_SUMMARY_ID,
			SUM(dst.SAVING_INSTALLMENT) SAVING_INSTALLMENT,
			SUM(dst.WITHDRAWAL) WITHDRAWAL,
			SUM(dst.MONTHLY_INTEREST) MONTHLY_INTEREST
			FROM DAILY_SAVING_TRX dst
			WHERE dst.OFFICE_ID=officeID AND dst.ORGANIZATION_ID=orgID
			GROUP BY SAVING_SUMMARY_ID,TRANSACTION_DATE 
			HAVING SUM(dst.WITHDRAWAL)>0) d ON s.SAVING_SUMMARY_ID=d.SAVING_SUMMARY_ID
		Where (s.DEPOSIT+s.CUM_INTEREST-s.WITHDRAWAL+s.PENALTY)=0 
		AND s.OFFICE_ID=officeID AND s.ORGANIZATION_ID=orgID
		--Where (s.Deposit+s.CumInterest-s.Withdrawal+d.SavingInstallment+d.MonthlyInterest-d.Withdrawal)<=0 and s.OfficeID=@lcl_OfficeID
		--And d.TransactionDate=CONVERT(DATETIME, @lcl_BusinessDate, 102)
		AND s.SAVING_STATUS=1;
	
		TYPE class IS RECORD (
			office_id NUMBER(22),
			member_id NUMBER(32),
			center_id NUMBER(19),
			no_of_account NUMBER(10),
			saving_summary_id NUMBER(32),
			transaction_date DATE
		);
	
		TYPE records IS TABLE OF class INDEX BY BINARY_INTEGER;
		v_records records;
BEGIN
	OPEN cur;
	
	FETCH cur BULK COLLECT INTO v_records;
	IF(v_records.COUNT>0) THEN
		FOR i IN 1..v_records.COUNT LOOP
			ACCOUNTS.ACCOUNT_CLOSE(
				v_records(i).office_id,
				v_records(i).member_id,
				v_records(i).center_id,
				v_records(i).no_of_account,
				v_records(i).saving_summary_id,
				v_records(i).transaction_date
			);
		END LOOP;
	END IF;

	CLOSE cur;

END;
END ACCOUNTS;