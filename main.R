set.seed(2)
library(dplyr)
library(tidyr)
library(lubridate)
library(readr)

svd_preprocess <- function(data, ncomps) {
  unique_depts = unique(data["Dept"])
  for (i in 1:nrow(unique_depts)) {
    dept_data = data %>%
      select(Store, Dept, Date, Weekly_Sales) %>%
      spread(Date, Weekly_Sales) %>%
      filter(Dept == unique_depts$Dept[i])
    
    dept_data[is.na(dept_data)] = 0
    
    if (nrow(dept_data) > ncomps) {
      store_mean = rowMeans(dept_data[, 3:ncol(dept_data)])
      dept_data[, 3:ncol(dept_data)] = dept_data[, 3:ncol(dept_data)] - store_mean
      s = svd(dept_data[, 3:ncol(dept_data)])
      s$d[ncomps:length(s$d)] = 0
      D = diag(s$d)
      dept_data[, 3:ncol(dept_data)] = (s$u %*% D %*% t(s$v)) + store_mean
    }
    if (i == 1) {
      dept_svd = dept_data
    }
    else {
      dept_svd = rbind(dept_svd, dept_data)
    }
  }
  dept_svd = dept_svd %>%
    gather(Date, Weekly_Sales, -Store, -Dept)
  return(dept_svd)
}

mypredict <- function() {
  start_date <- ymd("2011-03-01") %m+% months(2 * (t - 1))
  end_date <- ymd("2011-05-01") %m+% months(2 * (t - 1))
  test_current <- test %>%
    filter(Date >= start_date & Date < end_date) %>%
    select(-IsHoliday)
  
  train = svd_preprocess(train, 8)
  
  # find the unique pairs of (Store, Dept) combo that appeared in both training and test sets
  train_pairs <- train[, 1:2] %>% count(Store, Dept) %>% filter(n != 0)
  test_pairs <- test_current[, 1:2] %>% count(Store, Dept) %>% filter(n != 0)
  unique_pairs <- intersect(train_pairs[, 1:2], test_pairs[, 1:2])
  
  # pick out the needed training samples, convert to dummy coding, then put them into a list
  train_split <- unique_pairs %>% 
    left_join(train, by = c('Store', 'Dept')) %>% 
    mutate(Wk = factor(ifelse(year(Date) == 2010, week(Date) - 1, week(Date)), levels = 1:52)) %>% 
    mutate(Yr = year(Date))
  train_split = as_tibble(model.matrix(~ Weekly_Sales + Store + Dept + Yr + Wk, train_split)) %>% group_split(Store, Dept)
  
  # do the same for the test set
  test_split <- unique_pairs %>% 
    left_join(test_current, by = c('Store', 'Dept')) %>% 
    mutate(Wk = factor(ifelse(year(Date) == 2010, week(Date) - 1, week(Date)), levels = 1:52)) %>% 
    mutate(Yr = year(Date))
  test_split = as_tibble(model.matrix(~ Store + Dept + Yr + Wk, test_split)) %>% mutate(Date = test_split$Date) %>% group_split(Store, Dept)
  
  # pre-allocate a list to store the predictions
  test_pred <- vector(mode = "list", length = nrow(unique_pairs))
  
  # perform regression for each split
  for (i in 1:nrow(unique_pairs)) {
    tmp_train <- train_split[[i]]
    tmp_test <- test_split[[i]]
    
    tmp_train$"Yr^2" = tmp_train$Yr^2
    tmp_test$"Yr^2" = tmp_test$Yr^2
    
    mycoef <- lm.fit(as.matrix(tmp_train[, -(2:4)]), tmp_train$Weekly_Sales)$coefficients
    mycoef[is.na(mycoef)] <- 0
    
    tmp_pred <- mycoef[1] + as.matrix(tmp_test[, 4:57][-53]) %*% mycoef[-1]
    
    test_pred[[i]] <- cbind(tmp_test[, 2:3], Date = tmp_test$Date, Weekly_Pred = tmp_pred[, 1])
  }
  
  # turn the list into a table at once
  test_pred <- bind_rows(test_pred)
  return(test_pred)
}

# read in train / test dataframes
train <- readr::read_csv('train_ini.csv')
test <- readr::read_csv('test.csv')

# wae: record weighted mean absolute error WMAE
num_folds <- 10
wae <- rep(0, num_folds)

for (t in 1:num_folds) {
  test_pred <- mypredict()
  
  # read new data from fold_t 
  fold_file <- paste0('fold_', t, '.csv')
  new_train <- readr::read_csv(fold_file, 
                               col_types = cols())
  
  # extract predictions matching up to the new data
  scoring_tbl <- new_train %>% 
    left_join(test_pred, by = c('Date', 'Store', 'Dept'))
  
  # compute WMAE
  actuals <- scoring_tbl$Weekly_Sales
  preds <- scoring_tbl$Weekly_Pred
  preds[is.na(preds)] <- 0
  weights <- if_else(scoring_tbl$IsHoliday, 5, 1)
  wae[t] <- sum(weights * abs(actuals - preds)) / sum(weights)
  
  # update train data and get ready to predict at (t+1)
  train <- train %>% add_row(new_train)
}

print(wae)
mean(wae)
