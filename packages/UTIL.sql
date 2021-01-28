CREATE OR REPLACE PACKAGE MFIDSK.UTIL
AS
/**
 * Author Himel
 */
 FUNCTION GET_FIRST_DATE(myDate DATE) RETURN DATE;
 FUNCTION GET_LAST_DATE(myDate DATE) RETURN DATE;
 FUNCTION GET_DAY_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC;
 FUNCTION GET_MONTH_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC;
 FUNCTION GET_YEAR_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC;
 FUNCTION GET_DAY_DIFF(date1 date, date2 date) RETURN INTEGER;
 FUNCTION GET_MONTH_DIFF(date1 date, date2 date) RETURN INTEGER;
END UTIL;

CREATE OR REPLACE PACKAGE BODY MFIDSK.UTIL
AS
/**
 * Author Himel
 */
/**
 * Get Day difference between date
 */
FUNCTION GET_DAY_DIFF(date1 DATE, date2 DATE) RETURN INTEGER IS
 dayDiff INTEGER;
BEGIN
	SELECT ROUND(date1 - date2) INTO dayDiff FROM DUAL;
	RETURN dayDiff;
END;
/**
 * Get Month Difference betweeen date
 * 
 */
FUNCTION GET_MONTH_DIFF(date1 date, date2 date) RETURN INTEGER IS
 monthDiff INTEGER;
BEGIN
	SELECT ABS(FLOOR(MONTHS_BETWEEN(date1 , date2))) INTO monthDiff FROM DUAL;
	RETURN monthDiff;
END;
/**
 * Get first date of the month from given date.
 */
FUNCTION GET_FIRST_DATE(myDate DATE) 
RETURN DATE IS
firstDate VARCHAR(30);
date1 varchar2(60);
BEGIN
	date1 := TO_CHAR(myDate,'YYYY-MM-DD');
	SELECT TRIM(SUBSTR(date1,0,4))||'-'||TRIM(SUBSTR(date1,6,2))||'-01' INTO firstDate FROM dual;
	RETURN TO_DATE(TRIM(firstDate),'YYYY-MM-DD');
END;
/**
 * Get last date of the month from given date
 */
FUNCTION GET_LAST_DATE(myDate DATE)
RETURN DATE IS
lastDate varchar2(60);
date1 varchar2(60);
lDate varchar2(2);
n_year NUMBER(4);
n_month NUMBER(2);
s_month NUMBER(2);

BEGIN
	date1 := TO_CHAR(myDate,'YYYY-MM-DD');
	SELECT TO_NUMBER(SUBSTR(date1,0,4)),TO_NUMBER(SUBSTR(date1,6,2)),SUBSTR(date1,6,2)
	INTO n_year,n_month,s_month FROM dual;
	
	
	IF(n_month = 1 OR n_month = 3 OR n_month = 5 OR
	  n_month = 7 OR n_month = 8 OR n_month = 10 OR n_month = 12) THEN
		lDate := '31';
	END IF;

	IF(n_month = 4 OR n_month = 6 OR n_month = 9 OR n_month = 11) THEN
		lDate := '30';
	END IF;

	IF (n_month=2) THEN
		IF(MOD(n_year,4) = 0)THEN
			lDate := '29';
		ELSE
			lDate := '28';
		END IF;
	END IF;
	lastDate := TRIM(n_year) || '-' || TRIM(n_month) || '-' || TRIM(lDate);
	RETURN TO_DATE(lastDate,'YYYY-MM-DD');
END;

FUNCTION GET_DAY_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC IS
s_day NUMBER(2);
BEGIN
	SELECT EXTRACT(DAY FROM myDate) INTO s_day FROM DUAL;
	RETURN s_day;
END;

FUNCTION GET_MONTH_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC IS
s_month NUMBER(2);
BEGIN
	SELECT EXTRACT(MONTH FROM myDate) INTO s_month FROM DUAL;
	RETURN s_month;
END;

FUNCTION GET_YEAR_FROM_DATE(myDate DATE) RETURN NUMBER DETERMINISTIC IS
s_year NUMBER(4);
BEGIN
	SELECT EXTRACT(YEAR FROM myDate) INTO s_year FROM DUAL;
	RETURN s_year;
END;
END UTIL;