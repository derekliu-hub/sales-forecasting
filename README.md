# Walmart Store Sales Forecasting
### Objective
The sales.csv dataset provides the historical sales data for 45 Walmart stores located in different regions with each store containing many different departments. It has 421570 rows in total and 5 columns. The columns are Store, Dept, Date, Weekly_Sales, and IsHoliday. Store and Dept contain integers that id which store and department generated the sales. IsHoliday is a Boolean column that indicates whether that week was a holiday. Train_ini.csv, test.csv, and folds 1 to 10 were generated with the code in split_data and are all subsets of sales. The goal was to build a model that could predict the future weekly sales for each department in each store based on this historical data. Testing the model across the different folds worked as such:
* For t = 1, predict 2011-03 to 2011-04 based on data from 2010-02 to 2011-02 (train_ini.csv)
* For t = 2, predict 2011-05 to 2011-06 based on data from 2010-02 to 2011-04 (train_ini.csv, fold_1.csv)
* For t = 3, predict 2011-07 to 2011-08 based on data from 2010-02 to 2011-06 (train_ini.csv, fold_1.csv, fold_2.csv)
……
* For t = 10, predict 2012-09 to 2012-10 based on data from 2010-02 to 2012-08 (train_ini.csv, fold_1.csv, fold_2.csv, …, fold_9.csv)
### Pre-Processing
SVD was applied to reduce noise in the training data because the sales pattern of a department seemed similar across stores. The procedure for doing so is as follows:
1. Arrange the data from a single department as an m x n matrix where m is the number of stores that have this department and n is the number of weeks.
2. Subtract the row means from the new matrix and apply SVD on it.
3. Choose the top 8 components and obtain a reduced rank (or smoothed) version of the matrix by computing UDV<sup>T</sup> where D is a diagonal matrix with all diagonal entries after the first 8 set to 0. Add the row means previously subtracted back to the smoothed matrix.

The intuition behind this is that the shared top PCs are probably signals, while the PCs associated with small variances are probably noise. This procedure was done for each department and all the resulting matrices were reshaped into the original structure of the data before being combined into a single matrix. Any missing values were replaced with 0.
### Fitting The Model
New Week and Year variables were created where Year is a numerical variable and Week is a categorical variable (i.e. 52 or 53 levels for each week in the year). After that was done, a regression model was fitted on the training data with the form Y ~ Year + Week + Year<sup>2</sup>. The quadratic term was included because there may be non-linear effects on sales year-over-year.
### Results
The model’s performance was evaluated using weighted mean absolute error (WMAE). If the week is a holiday (e.g. Super Bowl, Labor Day, Thanksgiving, Christmas), then the weight is 5. Otherwise, it is 1. The table below shows the model's WMAE across all 10 folds.
| Fold #  |  WMAE   |
|---------|---------|
| 1       | 1921.32 |
| 2       | 1367.89 |
| 3       | 1381.48 |
| 4       | 1529.16 |
| 5       | 2318.41 |
| 6       | 1627.34 |
| 7       | 1683.64 |
| 8       | 1359.92 |
| 9       | 1341.85 |
| 10      | 1342.50 |

Average WMAE over the 10 folds is 1587.35.