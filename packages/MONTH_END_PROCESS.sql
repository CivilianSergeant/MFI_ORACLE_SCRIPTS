CREATE OR REPLACE PACKAGE MFIDSK.MONTH_END_PROCESS
AS
-- Package header
PROCEDURE UPDATE_DAILY_SAVING_TRX_BALANCE(monthEndDate DATE, dayDiff NUMBER, 
	officeID NUMBER, orgID NUMBER);
END MONTH_END_PROCESS;

CREATE OR REPLACE PACKAGE BODY MFIDSK.MONTH_END_PROCESS
AS
-- Package body
PROCEDURE UPDATE_DAILY_SAVING_TRX_BALANCE(monthEndDate IN DATE, dayDiff IN NUMBER, 
	officeID IN NUMBER, orgID IN NUMBER)
IS
ex EXCEPTION;
PRAGMA exception_init(ex,-20001);
spName varchar(80) := SYSDATE || ' UPDATE_DAILY_SAVING_TRX_BALANCE: ';
BEGIN
	
	MERGE INTO DAILY_SAVING_TRX t
			USING (
			SELECT s.OPENING_DATE,dst.OFFICE_ID,
				dst.MEMBER_ID,dst.PRODUCT_ID,dst.SAVING_SUMMARY_ID,dst.CENTER_ID,dst.NO_OF_ACCOUNT,
				(CASE WHEN UTIL.GET_DAY_DIFF(monthEndDate,s.OPENING_DATE)>=dayDiff
				THEN dst.BALANCE ELSE 0 END) BALANCE  
				FROM DAILY_SAVING_TRX dst INNER JOIN SAVING_SUMMARY s 
				ON (dst.PRODUCT_ID = s.PRODUCT_ID) 
					AND (dst.MEMBER_ID = s.MEMBER_ID) 
					AND (dst.CENTER_ID= s.CENTER_ID)  
					AND (dst.OFFICE_ID = s.OFFICE_ID) 
					AND dst.NO_OF_ACCOUNT = s.NO_OF_ACCOUNT 
					AND dst.SAVING_SUMMARY_ID = s.SAVING_SUMMARY_ID 
				WHERE dst.OFFICE_ID=officeID AND s.SAVING_STATUS = 1 AND dst.ORGANIZATION_ID=orgID) s
				ON (t.SAVING_SUMMARY_ID = s.SAVING_SUMMARY_ID AND 
				t.MEMBER_ID = s.MEMBER_ID AND t.PRODUCT_ID = s.PRODUCT_ID AND 
				t.CENTER_ID = s.CENTER_ID AND t.OFFICE_ID = s.OFFICE_ID AND
				t.NO_OF_ACCOUNT = s.NO_OF_ACCOUNT)
				WHEN MATCHED THEN
				UPDATE SET t.BALANCE = s.BALANCE;
			
EXCEPTION
	WHEN OTHERS THEN
	WRITE_LOG(spName || SQLERRM);
	raise_application_error(-20001,spName || SQLERRM);			
			
END;
END MONTH_END_PROCESS;