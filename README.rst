Tomcat on Apache - Java Servlet and JSP Platform
================================================

`Tomcat`_ is a servlet container that implements the Java Servlet and
the JavaServer Pages (JSP) specifications, and provides a "pure Java"
HTTP web server environment for Java code to run in. Tomcat powers
numerous large-scale, mission-critical web applications across a diverse
range of industries and organizations.

This appliance integrates Tomcat with the Apache web server. When a
fully featured web server is not required, consider using the
`Standalone Tomcat Appliance`_.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Tomcat on Apache configurations:
   
   - TurnKey web control panel in /var/lib/tomcat9/webapps/cp

     The default Apache index file (/var/www/index.html) uses javascript
     to redirect the root web page to the control panel::

        window.location = "/cp/"

   - All components installed from package management.
   - Using OpenJDK Java runtime.
   - Deployed web applications in /var/lib/tomcat9/webapps.
   - TurnKey web control panel in /var/lib/tomcat9/webapps/cp.
   - JSP console output sent to syslog (/var/log/syslog).
   - Created Tomcat admin/manager roles and admin user.
   - Use Apache2 Jk loadbalancer connector (performance).
   - JkMounts for admin, manager, host-manager applications
     (convenience).
   - Bind Tomcat AJP connector to localhost (security).
   - Removed Tomcat HTTP connector listener (security).
   - Set system wide Tomcat and Java environment variables.

- Includes MySQL.
- SSL support out of the box.
- Includes Webmin module for configuring Apache2 and MySQL.

See the `Tomcat on Apache docs`_ for further details.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Tomcat administration applications: username **admin**


.. _Tomcat: https://tomcat.apache.org
.. _Standalone Tomcat Appliance: https://www.turnkeylinux.org/tomcat
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Tomcat on Apache docs: https://www.turnkeylinux.org/docs/tomcat-apache
