CREATE OR REPLACE PACKAGE DSTR
AS
    FUNCTION DSTR_DEPOSITOR(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_MONTHLY_INTEREST(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_NON_DEPOSITOR(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_OPENING_BALANCE(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_PENALTY(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_PRODUCT(officeid int) RETURN varchar;
    FUNCTION DSTR_SAVING_DEPOSIT(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_SAVING_INSTALLMENT(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_SAVING_WITHDRAWAL(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_TRANSFER_DEPOSIT(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_TRANSFER_WITHDRAWAL(pid NUMBER) RETURN NUMBER;
    FUNCTION DSTR_WITHDRAWER(pid NUMBER) RETURN NUMBER;
    FUNCTION CLOSING_BALANCE(pid IN number) RETURN NUMBER;
END DSTR;

CREATE OR REPLACE PACKAGE BODY DSTR
AS
    FUNCTION DSTR_DEPOSITOR(pid IN number) RETURN NUMBER AS
    depositor number(18,0) := 0;
    BEGIN
    --depositor
        SELECT count(cm.Member_ID) INTO depositor from (SELECT dst.Member_ID from Daily_Saving_Trx dst 
        where Product_ID = pid and dst.Saving_Installment <> 0 GROUP by Member_ID) cm;

        RETURN depositor;

    END;

    FUNCTION DSTR_MONTHLY_INTEREST(pid IN number) RETURN NUMBER AS 
    monthly_Interest number(18,0) :=0;
    BEGIN 
        SELECT sum(dst.Monthly_Interest) into monthly_Interest 
        from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;

        RETURN monthly_Interest;
    END;

    FUNCTION DSTR_NON_DEPOSITOR(pid IN number) RETURN NUMBER AS
    non_depositor number(18,0) := 0;
    BEGIN
    --non depositor
        SELECT count(cm.Member_ID) INTO non_depositor from (SELECT dst.Member_ID from Daily_Saving_Trx dst 
        where Product_ID = pid and dst.Saving_Installment = 0 GROUP by Member_ID) cm;
        
        RETURN non_depositor;

    END;

    FUNCTION DSTR_OPENING_BALANCE(pid IN number) RETURN NUMBER AS 
    opening_balance NUMBER(18,0) := 0;
    BEGIN
        SELECT sum((ss.Deposit + ss.Cum_Interest + ss.Penalty)-ss.Withdrawal) into opening_Balance 
            from Saving_Summary ss WHERE ss.PRODUCT_ID = pid;
        
        RETURN opening_balance;
    END;

    FUNCTION DSTR_PENALTY(pid IN number) RETURN NUMBER AS 
    penalty number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Penalty) into penalty from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;
        
        RETURN penalty;
    END;

    FUNCTION DSTR_PRODUCT(officeid IN int) RETURN varchar AS 
    productName varchar(100);
    BEGIN
        SELECT  p.Product_Code || ' ' || p.Product_Name INTO productName  
        from products p inner join Product_Mappings pm on pm.Product_ID = p.Product_ID
        where pm.Office_ID = officeid 
        and p.Product_Type = 0 
        and p.Is_Active = 1;

        RETURN productName;
    END;

    FUNCTION DSTR_SAVING_DEPOSIT(pid IN number) RETURN NUMBER AS 
    savings_deposit number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Deposit) into savings_deposit from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;
        
        RETURN savings_deposit;
    END;

    FUNCTION DSTR_SAVING_INSTALLMENT(pid IN number) RETURN NUMBER AS 
    savings_installment number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Saving_Installment) INTO savings_installment 
            from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;
        
        RETURN savings_installment;
    END;

    FUNCTION DSTR_SAVING_WITHDRAWAL(pid IN number) RETURN NUMBER AS 
    saving_withdrawal number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Withdrawal) into saving_withdrawal from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;

        RETURN saving_withdrawal;
    END;

    FUNCTION DSTR_TRANSFER_DEPOSIT(pid IN number) RETURN NUMBER AS 
    transfer_deposit number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Transfer_Deposit) into transfer_deposit 
        from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;
        
        RETURN transfer_deposit;
    END;

    FUNCTION DSTR_TRANSFER_WITHDRAWAL(pid IN number) RETURN NUMBER AS 
    transfer_Withdrawal number(18,0) := 0;
    BEGIN 
        SELECT sum(dst.Transfer_Withdrawal) into transfer_Withdrawal from Daily_Saving_Trx dst WHERE dst.PRODUCT_ID = pid;

        RETURN transfer_Withdrawal;
    END;

    FUNCTION DSTR_WITHDRAWER(pid IN number) RETURN NUMBER AS
    withdrawer number(18,0) := 0;
    BEGIN
    --withdrawer
    SELECT count(cm.Member_ID) into withdrawer from (SELECT dst.Member_ID 
        from Daily_Saving_Trx dst where Product_ID = pid and dst.Withdrawal <> 0 GROUP by Member_ID) cm;

        RETURN withdrawer;

    END;

    FUNCTION CLOSING_BALANCE(pid IN number) RETURN NUMBER AS 
	opening_balance NUMBER(18,0) := 0;
	savings_deposit NUMBER(18,0) := 0;
	transfer_deposit NUMBER(18,0) := 0;
	monthly_Interest NUMBER(18,0) := 0;
	penalty NUMBER(18,0) := 0;
	saving_withdrawal NUMBER(18,0) := 0;
	transfer_Withdrawal NUMBER(18,0) := 0;
	closing_amount number(18,0) := 0;

	BEGIN 
		SELECT DSTR.OPENING_BALANCE(pid) INTO opening_balance FROM DUAL;
		
		SELECT DSTR.SAVING_DEPOSIT(pid) INTO savings_deposit FROM DUAL ;
		
		SELECT DSTR.TRANSFER_DEPOSIT(pid) INTO transfer_deposit FROM DUAL;
		
		SELECT DSTR.MONTHLY_INTEREST(pid) INTO monthly_Interest FROM DUAL;
		
		SELECT DSTR.PENALTY(pid) INTO penalty FROM DUAL;
		
		SELECT DSTR.SAVING_WITHDRAWAL(pid) INTO saving_withdrawal FROM DUAL;
		
		SELECT DSTR.TRANSFER_WITHDRAWAL(pid) INTO transfer_Withdrawal FROM DUAL;
		
		closing_amount := ((opening_Balance+savings_deposit+transfer_deposit+monthly_Interest+penalty)-(saving_withdrawal+transfer_Withdrawal));
		
		RETURN closing_amount;
	
	END;

END DSTR;