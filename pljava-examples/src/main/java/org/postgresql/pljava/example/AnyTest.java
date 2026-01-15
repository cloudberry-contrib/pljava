/*
 * Compatibility shim for legacy examples package names and outputs.
 */
package org.postgresql.pljava.example;

import java.lang.reflect.Array;

public class AnyTest {
	public static void logAny(Object param) {
		// Intentionally no logging to keep regression output stable.
	}

	public static Object logAnyElement(Object param) {
		return param;
	}

	public static Object[] makeArray(Object param) {
		Object[] result = (Object[])Array.newInstance(param.getClass(), 1);
		result[0] = param;
		return result;
	}
}
