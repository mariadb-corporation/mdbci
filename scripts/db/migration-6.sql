ALTER TABLE sysbench_results DROP COLUMN General_statistics_total_time_taken_by_event_execution;
ALTER TABLE sysbench_results DROP COLUMN OLTP_test_statistics_other_operations;
ALTER TABLE sysbench_results DROP COLUMN OLTP_test_statistics_read_write_requests;
UPDATE db_metadata SET version = 6;
