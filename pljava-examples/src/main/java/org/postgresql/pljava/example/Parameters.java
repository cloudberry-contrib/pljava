/*
 * Compatibility shim for legacy examples package names and signatures.
 */
package org.postgresql.pljava.example;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Time;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.TimeZone;

public class Parameters {
	private static final TimeZone UTC = TimeZone.getTimeZone("UTC");

	public static Timestamp getTimestamp() {
		return new Timestamp(System.currentTimeMillis());
	}

	public static String print(Date value) {
		SimpleDateFormat fmt =
			new SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.US);
		fmt.setTimeZone(UTC);
		return fmt.format(value);
	}

	public static String print(Time value) {
		SimpleDateFormat fmt =
			new SimpleDateFormat("HH:mm:ss z Z", Locale.US);
		fmt.setTimeZone(UTC);
		return fmt.format(value);
	}

	public static String print(Timestamp value) {
		SimpleDateFormat fmt =
			new SimpleDateFormat("EEEE, MMMM d, yyyy h:mm:ss a z", Locale.US);
		fmt.setTimeZone(UTC);
		return fmt.format(value);
	}

	public static String print(String value) {
		return value;
	}

	public static byte[] print(byte[] value) {
		return value;
	}

	public static short print(short value) {
		return value;
	}

	public static short[] print(short[] value) {
		return value;
	}

	public static int print(int value) {
		return value;
	}

	public static int[] print(int[] value) {
		return value;
	}

	public static long print(long value) {
		return value;
	}

	public static long[] print(long[] value) {
		return value;
	}

	public static float print(float value) {
		return value;
	}

	public static float[] print(float[] value) {
		return value;
	}

	public static double print(double value) {
		return value;
	}

	public static double[] print(double[] value) {
		return value;
	}

	public static Integer[] print(Integer[] value) {
		return value;
	}

	public static int addOne(Integer value) {
		return value.intValue() + 1;
	}

	public static Integer nullOnEven(int value) {
		return (value % 2) == 0 ? null : value;
	}

	public static double addNumbers(short a, int b, long c, BigDecimal d,
		BigDecimal e, float f, double g) {
		return d.doubleValue() + e.doubleValue() + a + b + c + f + g;
	}

	public static int countNulls(Integer[] intArray) throws SQLException {
		int nullCount = 0;
		int top = intArray.length;
		for (int idx = 0; idx < top; ++idx) {
			if (intArray[idx] == null) {
				nullCount++;
			}
		}
		return nullCount;
	}

	public static int countNulls(ResultSet input) throws SQLException {
		int nullCount = 0;
		int top = input.getMetaData().getColumnCount();
		for (int idx = 1; idx <= top; ++idx) {
			input.getObject(idx);
			if (input.wasNull()) {
				nullCount++;
			}
		}
		return nullCount;
	}
}
