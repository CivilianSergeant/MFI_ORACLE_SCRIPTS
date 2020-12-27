CREATE OR REPLACE PACKAGE MFIDSK.MFI_CALCULATION 
AS
	FUNCTION GET_LOAN_DUE(
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
	) RETURN NUMBER;

	FUNCTION GET_LOAN_PAID(
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
	) RETURN NUMBER;

	FUNCTION GET_INT_DUE(
		calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
		principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
		loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
		loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
		intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
		paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
		intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
		installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
		installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
		duration IN LOAN_SUMMARY.DURATION%TYPE,
		startBusinessDate IN DATE
	) RETURN NUMBER;

	FUNCTION GET_INT_PAID(
		calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
		principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
		loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
		loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
		intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
		paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
		intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
		installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
		installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
		duration IN LOAN_SUMMARY.DURATION%TYPE,
		startBusinessDate IN DATE
	) RETURN NUMBER;

	FUNCTION GET_DURATION_OVER_LOAN_DUE(
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
	) RETURN NUMBER;

	FUNCTION GET_DURATION_OVER_INT_DUE(
		calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
		principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
		loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
		loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
		interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
		intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
		paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
		intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
		installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
		installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
		duration IN LOAN_SUMMARY.DURATION%TYPE,
		startBusinessDate IN DATE
	) RETURN NUMBER;
END MFI_CALCULATION;


CREATE OR REPLACE PACKAGE BODY MFIDSK.MFI_CALCULATION 
AS
/**
 * 2020-12-27
 * Rewrite By Himel
 * Get Loan Due
 */
FUNCTION GET_LOAN_DUE(
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
			loanDue := recoverable - interestAmount;
		END IF;
	
	-- for declined
	ELSIF calcMethod = 'D' THEN
		
--		IF (calcMethod = 'F') THEN
--			intChargeAmount := intCharge;
--		END IF;
--	
--		IF (calcMethod = 'A') THEN
--			IF ((recoverable-interestAmount) > principalBalance) THEN
--				intChargeAmount := principalBalance;
--			ELSE
--				intChargeAmount := recoverable-interestAmount;
--			END IF;
--		END IF;
	
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
		IF ((principalLoan + intChargeAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
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
/**
 * 2020-12-27
 * Rewrite By Himel
 * GET LOAN PAID
 */
FUNCTION GET_LOAN_PAID(
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

loanPaid NUMBER(18,2) := 0;
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
			loanPaid := loanInstallment;
		ELSE
			loanPaid := principalBalance;
		END IF;
	
	-- for amortization
	ELSIF calcMethod = 'A' THEN
		IF ((recoverable - interestAmount) > principalBalance) THEN
			loanPaid := principalBalance;
		ELSE
			loanPaid := recoverable - interestAmount;
		END IF;
	
	-- for declined
	ELSIF calcMethod = 'D' THEN
		
--		IF (calcMethod = 'F') THEN
--			intChargeAmount := intCharge;
--		END IF;
--	
--		IF (calcMethod = 'A') THEN
--			IF ((recoverable - interestAmount) > principalBalance) THEN
--				intChargeAmount := principalBalance;
--			ELSE
--				intChargeAmount := recoverable-interestAmount;
--			END IF;
--		END IF;
	
		IF (calcMethod = 'D') THEN
			intChargeAmount := intCharge + intChargeAmountYearly;
		END IF;
		
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			loanPaid := loanInstallment;
		ELSE
			loanPaid := principalBalance;
		END IF;
	
	-- For Amortization Fixed
	ELSIF calcMethod = 'E' THEN
		intChargeAmount := intCharge + interestAmount;
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			loanPaid := loanInstallment;
		ELSE
			loanPaid := principalBalance;
		END IF;
	
	-- For Reduce method
	ELSIF calcMethod = 'R' THEN
		intChargeAmount := intCharge + interestAmount;
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF ((principalLoan + intChargeAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
			loanPaid := loanInstallment;
		ELSE
			loanPaid := principalBalance;
		END IF;
	
	-- For Housing Method
	ELSIF calcMethod = 'H' THEN
		intChargeAmount := intCharge + intChargeAmountYearly;
		IF(recoverable - (intChargeAmount-intPaid))<0 THEN
			loanPaid := 0;
		ELSE
			IF (recoverable - (intChargeAmount-intPaid)) > principalBalance THEN
				loanPaid := principalBalance;
			ELSE
				loanPaid := recoverable - intChargeAmountYearly;
			END IF;		
		END IF;
	END IF;

		
	RETURN loanPaid;
END;
/**
 * 2020-12-27
 * Rewrite By Himel
 * Get Int Due 
 */
FUNCTION GET_INT_DUE(
	calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
	principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
	loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
	loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
	intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
	paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
	intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
	installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
	installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
	duration IN LOAN_SUMMARY.DURATION%TYPE,
	startBusinessDate IN DATE
) RETURN NUMBER AS

vIntDue NUMBER(18,2) := 0;
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
			
	IF calcMethod = 'A'  THEN
		vIntDue := interestAmount;
	
	ELSIF  calcMethod = 'F' THEN
		IF ((intCharge - intPaid) < intInstallment) THEN
			vIntDue := (intInstallment - (intCharge - intPaid));
		ELSE
			vIntDue := 0;
		END IF;
		
		IF((intCharge-intPaid)> intInstallment) THEN
			vIntDue := vIntDue + intInstallment;
		ELSE
			vIntDue := vIntDue + (intCharge-intPaid);
		END IF;
	
	ELSIF calcMethod = 'D' THEN
		
		IF ((principalLoan + intCharge + intChargeAmountYearly)-cumPaid) > recoverable THEN
			vIntDue := intInstallment;
		ELSE
			vIntDue := (intCharge + intChargeAmountYearly) - intPaid;
		END IF;
	
	ELSIF calcMethod = 'E' THEN
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > recoverable THEN
			vIntDue := intInstallment;
		ELSE
			vIntDue := intCharge + interestAmount - intPaid;
		END IF;
	
	ELSIF calcMethod = 'R' THEN
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
			vIntDue := tempInterestAmount; 
		ELSE
			vIntDue := (intCharge + interestAmount) - intPaid; 
		END IF;
	
	ELSIF calcMethod = 'H' THEN
		IF ((installmentNo+1) = duration) THEN
			vIntDue := (intCharge + intChargeAmountYearly) - intPaid;
		ELSE
			vIntDue := intChargeAmountYearly;
		END IF;
	END IF;

	RETURN vIntDue;
END;
/**
 * 2020-12-27
 * Rewrite By Himel
 * Get Int PAID 
 */
FUNCTION GET_INT_PAID(
	calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
	principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
	loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
	loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
	intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
	paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
	intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
	installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
	installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
	duration IN LOAN_SUMMARY.DURATION%TYPE,
	startBusinessDate IN DATE
) RETURN NUMBER AS

vIntPaid NUMBER(18,2) := 0;
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
			
	IF calcMethod = 'A'  THEN
		vIntPaid := interestAmount;
	
	ELSIF  calcMethod = 'F' THEN
		IF ((intCharge - intPaid) < intInstallment) THEN
			vIntPaid := (intInstallment - (intCharge - intPaid));
		ELSE
			vIntPaid := 0;
		END IF;
		
		IF((intCharge-intPaid)> intInstallment) THEN
			vIntPaid := vIntPaid + intInstallment;
		ELSE
			vIntPaid := vIntPaid + (intCharge-intPaid);
		END IF;
	
	ELSIF calcMethod = 'D' THEN
		
		IF ((principalLoan + intCharge + intChargeAmountYearly)-cumPaid) > recoverable THEN
			vIntPaid := intInstallment;
		ELSE
			vIntPaid := (intCharge + intChargeAmountYearly) - intPaid;
		END IF;
	
	ELSIF calcMethod = 'E' THEN
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > recoverable THEN
			vIntPaid := intInstallment;
		ELSE
			vIntPaid := intCharge + interestAmount - intPaid;
		END IF;
	
	ELSIF calcMethod = 'R' THEN
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
			vIntPaid := tempInterestAmount; 
		ELSE
			vIntPaid := (intCharge + interestAmount) - intPaid; 
		END IF;
	
	ELSIF calcMethod = 'H' THEN
		IF ((installmentNo+1) = duration) THEN
			vIntPaid := (intCharge + intChargeAmountYearly) - intPaid;
		ELSE
			vIntPaid := intChargeAmountYearly;
		END IF;
	END IF;

	RETURN vIntPaid;
END;
/**
 * 2020-12-27
 * Rewrite By Himel
 * Get Duration Over Loan Due
 */
FUNCTION GET_DURATION_OVER_LOAN_DUE(
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

vDurOverLoanDue NUMBER(18,2) := 0;
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
			
	IF calcMethod = 'F' THEN
		IF (principalBalance > loanInstallment) THEN
			vDurOverLoanDue := loanInstallment;
		ELSE
			vDurOverLoanDue := principalBalance;
		END IF;

	ELSIF calcMethod = 'A' THEN
		IF ((recoverable - interestAmount) > principalBalance) THEN
			vDurOverLoanDue := principalBalance;
		ELSE
			vDurOverLoanDue := recoverable - interestAmount;
		END IF;
	
	-- for declined
	ELSIF calcMethod = 'D' THEN
		
--		IF (calcMethod = 'F') THEN
--			intChargeAmount := intCharge;
--		END IF;
--	
--		IF (calcMethod = 'A') THEN
--			IF ((recoverable-interestAmount) > principalBalance) THEN
--				intChargeAmount := principalBalance;
--			ELSE
--				intChargeAmount := recoverable-interestAmount;
--			END IF;
--		END IF;
	
		IF (calcMethod = 'D') THEN
			intChargeAmount := intCharge + intChargeAmountYearly;
		END IF;
		
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			vDurOverLoanDue := loanInstallment;
		ELSE
			vDurOverLoanDue := principalBalance;
		END IF;
	
	-- For Amortization Fixed
	ELSIF calcMethod = 'E' THEN
		intChargeAmount := intCharge + interestAmount;
		IF ((principalLoan + intChargeAmount) - cumPaid) > recoverable THEN
			vDurOverLoanDue := loanInstallment;
		ELSE
			vDurOverLoanDue := principalBalance;
		END IF;
	
	-- For Reduce method
	ELSIF calcMethod = 'R' THEN
		intChargeAmount := intCharge + interestAmount;
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF ((principalLoan + intChargeAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
			vDurOverLoanDue := loanInstallment;
		ELSE
			vDurOverLoanDue := principalBalance;
		END IF;
	
	-- For Housing Method
--	ELSIF calcMethod = 'H' THEN
--		intChargeAmount := intCharge + intChargeAmountYearly;
--		IF(recoverable - (intChargeAmount-intPaid))<0 THEN
--			loanDue := 0;
--		ELSE
--			IF (recoverable - (intChargeAmount-intPaid)) > principalBalance THEN
--				loanDue := principalBalance;
--			ELSE
--				loanDue := recoverable - intChargeAmountYearly;
--			END IF;		
--		END IF;
	END IF;

	RETURN vDurOverLoanDue;
END;
/**
 * 2020-12-27
 * Rewrite By Himel
 * Get Duration Over Int Due 
 */
FUNCTION GET_DURATION_OVER_INT_DUE(
	calcMethod IN PRODUCTS.INTEREST_CALCULATION_METHOD%TYPE,
	principalLoan IN LOAN_SUMMARY.PRINCIPAL_LOAN%TYPE,
	loanRepaid IN  LOAN_SUMMARY.LOAN_REPAID%TYPE,
	loanInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	intInstallment IN LOAN_SUMMARY.INT_INSTALLMENT%TYPE,
	interestRate IN LOAN_SUMMARY.INTEREST_RATE%TYPE,
	intCharge IN LOAN_SUMMARY.INT_CHARGE%TYPE,
	paymentFrequency IN PRODUCTS.PAYMENT_FREQUENCY%TYPE,
	intPaid IN LOAN_SUMMARY.INT_PAID%TYPE,
	installmentDate IN LOAN_SUMMARY.INSTALLMENT_DATE%TYPE,
	installmentNo IN LOAN_SUMMARY.INSTALLMENT_NO%TYPE,
	duration IN LOAN_SUMMARY.DURATION%TYPE,
	startBusinessDate IN DATE
) RETURN NUMBER AS

durOverIntDue NUMBER(18,2) := 0;
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
			
	IF calcMethod = 'A'  THEN
		durOverIntDue := interestAmount;
	
	ELSIF  calcMethod = 'F' THEN
		IF ((intCharge - intPaid) < intInstallment) THEN
			durOverIntDue := (intInstallment - (intCharge - intPaid));
		ELSE
			durOverIntDue := 0;
		END IF;
		
		IF((intCharge-intPaid)> intInstallment) THEN
			durOverIntDue := durOverIntDue + intInstallment;
		ELSE
			durOverIntDue := durOverIntDue + (intCharge-intPaid);
		END IF;
	
	ELSIF calcMethod = 'D' THEN
		
		IF ((principalLoan + intCharge + intChargeAmountYearly)-cumPaid) > recoverable THEN
			durOverIntDue := intInstallment;
		ELSE
			durOverIntDue := (intCharge + intChargeAmountYearly) - intPaid;
		END IF;
	
	ELSIF calcMethod = 'E' THEN
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > recoverable THEN
			durOverIntDue := intInstallment;
		ELSE
			durOverIntDue := intCharge + interestAmount - intPaid;
		END IF;
	
	ELSIF calcMethod = 'R' THEN
		tempInterestAmount  := NVL(principalBalance * interestRate/1200,0);
		IF((principalLoan + intCharge + interestAmount) - cumPaid) > (loanInstallment + tempInterestAmount) THEN
			durOverIntDue := tempInterestAmount; 
		ELSE
			durOverIntDue := (intCharge + interestAmount) - intPaid; 
		END IF;
	
	ELSIF calcMethod = 'H' THEN
		IF ((installmentNo+1) = duration) THEN
			durOverIntDue := (intCharge + intChargeAmountYearly) - intPaid;
		ELSE
			durOverIntDue := intChargeAmountYearly;
		END IF;
	END IF;

	RETURN durOverIntDue;
END;
END MFI_CALCULATION;