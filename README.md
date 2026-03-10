# SQL-Projects-for-Data-Analysis

A portfolio-ready collection of SQL projects designed to demonstrate strong analytical thinking and business problem-solving skills. These projects showcase end-to-end data analysis — from raw data exploration to data cleaning and advanced analytical reporting — including trend analysis, cumulative metrics, performance tracking, contribution (part-to-whole) analysis, and customer/data segmentation.

Built using advanced SQL techniques such as complex joins, CTEs, window functions, and views  each project highlights the ability to translate business questions into structured queries and actionable insights.

I avoid CTAS because it creates unnecessary physical tables that duplicate data and can become outdated if the source data changes. I also avoid subqueries because they can make queries harder to read, maintain, and sometimes less efficient compared to using CTEs or window functions.

Important Note: All projects were developed in SQL Server Management Studio (SSMS), stored locally, and version-controlled using Git (Bash) before being pushed to GitHub to ensure proper tracking and reproducibility.

Below you can find all the projects included on this repository and their corresponding link sources.

1. Cafe Sales - https://www.kaggle.com/datasets/ahmedmohamed2003/cafe-sales-dirty-data-for-cleaning-training

   This project analyzes ~10,000 cafe transactions (2023).  The workflow includes data cleaning, transformation, and quality checks in a silver layer, followed by the creation of a structured gold layer for analytics. Advanced SQL techniques such as CTEs, window functions, cumulative calculations, MoM analysis, AOV computation, revenue segmentation, and Pareto (80/20) analysis were applied to extract business insights.
