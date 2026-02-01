/*
 * Copyright (c) 2004-2020 Tada AB and other contributors, as listed below.
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the The BSD 3-Clause License
 * which accompanies this distribution, and is available at
 * http://opensource.org/licenses/BSD-3-Clause
 *
 * Contributors:
 *   Tada AB
 *   Chapman Flack
 */
package org.postgresql.pljava.example;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Enumeration;
import java.util.Properties;
import java.util.logging.Logger;

import org.postgresql.pljava.ObjectPool;
import org.postgresql.pljava.PooledObject;
import org.postgresql.pljava.ResultSetProvider;
import org.postgresql.pljava.SessionManager;

/**
 * Illustrates use of the {@code ResultSetProvider} interface to return
 * (key,value) rows from the {@code example.properties} file, also making use
 * of PL/Java's {@code ObjectPool} facility.
 * @author Thomas Hallgren
 */
public class UsingProperties implements ResultSetProvider.Large, PooledObject {
	private static Logger s_logger = Logger.getAnonymousLogger();

	public static ResultSetProvider getProperties() throws SQLException {
		ObjectPool<UsingProperties> pool =
			SessionManager.current().getObjectPool(UsingProperties.class);
		return (ResultSetProvider) pool.activateInstance();
	}

	private final Properties m_properties;

	private final ObjectPool<UsingProperties> m_pool;

	private Enumeration<?> m_propertyIterator;

	public UsingProperties(ObjectPool<UsingProperties> pool) throws IOException
	{
		m_pool = pool;
		m_properties = new Properties();

		URL urlloc = this.getClass().getResource("example.properties");
		s_logger.config("example.properties location is " + urlloc);
		Package pack = this.getClass().getPackage();
		String packageName = pack.getName()+" "+pack.getImplementationTitle() + " " + pack.getImplementationVendor() + " " + pack.getImplementationVersion();
		s_logger.config("UsingProperties package name: " + packageName );

		s_logger.config("** UsingProperties()");
		InputStream propStream = this.getClass().getResourceAsStream(
				"example.properties");
		if (propStream == null) {
			s_logger.config("example.properties was null");
		} else {
			m_properties.load(propStream);
			propStream.close();
			s_logger.config("example.properties has " + m_properties.size()
					+ " entries");
		}
		pack = m_properties.getClass().getPackage();
		packageName = pack.getName()+" "+pack.getImplementationTitle() + " " + pack.getImplementationVendor() + " " + pack.getImplementationVersion();
		s_logger.config("m_properties package name: " + packageName );
		if (pack.isSealed())
		{
			s_logger.config("package sealed");
		}
	}

	@Override
	public void activate() {
		s_logger.config("** UsingProperties.activate()");
		m_propertyIterator = m_properties.propertyNames();
	}

	@Override
	public boolean assignRowValues(ResultSet receiver, long currentRow)
			throws SQLException {
		if (m_propertyIterator == null || !m_propertyIterator.hasMoreElements()) {
			s_logger.fine("no more rows, returning false");
			return false;
		}
		String propName = (String) m_propertyIterator.nextElement();
		receiver.updateString(1, propName);
		receiver.updateString(2, m_properties.getProperty(propName));
		// s_logger.fine("next row created, returning true");
		return true;
	}

	@Override
	public void close() throws SQLException {
		m_pool.passivateInstance(this);
	}

	@Override
	public void passivate() {
		s_logger.config("** UsingProperties.passivate()");
		m_propertyIterator = null;
	}

	@Override
	public void remove() {
		s_logger.config("** UsingProperties.remove()");
		m_properties.clear();
	}
}
