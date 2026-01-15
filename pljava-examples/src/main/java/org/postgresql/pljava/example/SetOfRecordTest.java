/*
 * Compatibility shim for legacy examples package names.
 */
package org.postgresql.pljava.example;

import java.sql.SQLException;

import org.postgresql.pljava.ResultSetHandle;

public class SetOfRecordTest {
	public static ResultSetHandle executeSelect(String selectSQL)
		throws SQLException
	{
		return org.postgresql.pljava.example.annotation.SetOfRecordTest
			.executeSelect(selectSQL);
	}
}
