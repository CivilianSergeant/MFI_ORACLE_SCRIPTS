CREATE OR REPLACE FUNCTION MFIDSK.GET_LOAN_DUE(
	calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
	principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
	loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
	loanInstallment IN LOAN_SUMMARY.LOAN_INSTALLMENT%TYPE,
	intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
	intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
	paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
	intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
	installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
	startBusinessDate IN DATE
) RETURN NUMBER AS

loanDue NUMBER(18,2) := 0;
recoverable NUMBER(18,2) := 0;
calInterstRate NUMBER(18,2) := 0;
principalBalance NUMBER(18,2) := 0;
freqVAL NUMBER(10,0) := 0;
interestAmount NUMBER(18,2) := 0;
tempInterestAmount NUMBER(18,2) := 0;
intChargeAmountYearly NUMBER(18,2) := 0;
intChargeAmount NUMBER(18,0) := 0;
cumPaid NUMBER(18,2) := 0;
BEGIN
	
	principalBalance := (principalLoan - loanRepaid);
	recoverable := (loanInstallment + intInstallment);
	cumPaid := (loanRepaid + intPaid);
	
	IF paymentFrequency = 'W' THEN 
		freqVal := 4600;
	ELSE
		freqVal := 1200;
	END IF;

	interestAmount :=  ROUND((principalBalance * interestRate)/freqVal,0); 

    intChargeAmountYearly := ROUND((principalBalance * interestRate * 
				ABS(UTIL.GET_DAY_DIFF(installmentDate,startBusinessDate))) /36500,0);
	-- for flat 
	IF calcMethod = 'F' THEN
		IF (principalBalance > loanInstallment) THEN
			loanDue := loanInstallment;
		ELSE
			loanDue := principalLoan - loanRepaid;
		END IF;
	
	-- for amortization
	ELSIF calcMethod = 'A' THEN
		IF ((recoverable - interestAmount) > principalBalance) THEN
			loanDue := principalBalance;
		ELSE
			loanDue := interestAmount;
		END IF;
	
	-- for declined
	ELSIF calcMethod = 'D' THEN
		
		IF (calcMethod = 'F') THEN
			intChargeAmount := intCharge;
		END IF;
	
		IF (calcMethod = 'A') THEN
			IF (interestAmount > principalBalance) THEN
				intChargeAmount := principalBalance;
			ELSE
				intChargeAmount := interestAmount;
			END IF;
		END IF;
	
		IF (calcMethod = 'D') THEN
			intChargeAmount := intCharge + intChargeAmountYearly;
		END IF;
		
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			loanDue := loanInstallment;
		ELSE
			loanDue := principalBalance;
		END IF;
	
	-- For Amortization Fixed
	ELSIF calcMethod = 'E' THEN
		intChargeAmount := intCharge + interestAmount;
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			loanDue := loanInstallment;
		ELSE
			loanDue := principalBalance;
		END IF;
	
	-- For Reduce method
	ELSIF calcMethod = 'R' THEN
		intChargeAmount := intCharge + interestAmount;
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF ((principalLoan + intChargeAmount) - cumPaid) > (recoverable + tempInterestAmount) THEN
			loanDue := loanInstallment;
		ELSE
			loanDue := principalBalance;
		END IF;
	
	-- For Housing Method
	ELSIF calcMethod = 'H' THEN
		intChargeAmount := intCharge + intChargeAmountYearly;
		IF(recoverable - (intChargeAmount-intPaid))<0 THEN
			loanDue := 0;
		ELSE
			IF (recoverable - (intChargeAmount-intPaid)) > principalBalance THEN
				loanDue := principalBalance;
			ELSE
				loanDue := recoverable - intChargeAmountYearly;
			END IF;		
		END IF;
	END IF;

		
	RETURN loanDue;
END;