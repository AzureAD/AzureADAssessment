# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

<!-- ## Build -->

<!-- ## Test -->

## Power BI Template Updates

Updating the Power BI Template files (.pbit) can be tricky and must align with changes to the PowerShell data collection process. Power BI also has a [Data Privacy Firewall](https://docs.microsoft.com/en-us/power-query/dataprivacyfirewall) which prevents accidental data leakage between data sources. This firewall can sometimes prevent our assessment templates from loading when a query combines or joins data from multiple files, for example, oauth2PermissionGrants.csv + servicePrincipals.json. In our case, all the data sources have the same privacy level which should allow them to be combined but Power BI may still prevent loading with the following error:
Query 'Query1' (step 'Source') references other queries or steps, so it may not directly access a data source. Please rebuild this data combination.

One option to avoid this error is to turn off the Data Privacy Firewall by setting [Power BI Desktop privacy level](https://docs.microsoft.com/en-us/power-bi/enterprise/desktop-privacy-levels) to "Ignore the Privacy levels" when the template fails to load the data.

However, in order to avoid changing this setting whenever the template is instantiated, we can "rebuild this data combination" to avoid the firewall restrictions by introducing a proxy [function](https://docs.microsoft.com/en-us/power-query/custom-function) for each data sources used in the combination query. You can see some examples of this in the existing templates where queries will reference f_oauth2PermissionGrants() and f_servicePrincipals() which are proxy functions for the oauth2PermissionGrants and servicePrincipal data source tables rather than referencing those tables directly.
