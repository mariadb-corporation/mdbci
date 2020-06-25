CREATE TABLE target_builds (
  id INT AUTO_INCREMENT,
  run_id VARCHAR(64),
  start_time DATETIME,
  target VARCHAR(256),
  box VARCHAR(256),
  product VARCHAR(256),
  mariadb_version VARCHAR(256),
  test_code_commit_id VARCHAR(256),
  maxscale_commit_id VARCHAR(256),
  cmake_flags TEXT,
  maxscale_source VARCHAR(256) DEFAULT 'NOT FOUND',
  PRIMARY KEY(id)
);

ALTER TABLE target_builds ADD INDEX target (target);
ALTER TABLE target_builds ADD INDEX run_id (run_id);

INSERT INTO target_builds
SELECT DISTINCT
                NULL, NULL, NULL, target, box, product, mariadb_version, test_code_commit_id,
                maxscale_commit_id, cmake_flags, maxscale_source
FROM test_run;

UPDATE target_builds SET run_id=(SELECT uuid());

DELETE FROM results WHERE id IN (SELECT id FROM test_run WHERE start_time = 0);
DELETE FROM test_run WHERE start_time = 0;

ALTER TABLE test_run
ADD COLUMN target_build_id INT,
ADD FOREIGN KEY (target_build_id) REFERENCES target_builds(id);

UPDATE test_run AS tr, target_builds AS tb
SET tr.target_build_id = tb.id
WHERE tr.target = tb.target AND tr.box = tb.box AND tr.mariadb_version = tb.mariadb_version AND
      tr.test_code_commit_id = tb.test_code_commit_id AND tr.maxscale_commit_id = tb.maxscale_commit_id;

CREATE TEMPORARY TABLE start_times
SELECT target_build_id as id, MIN(start_time) AS start_time
FROM test_run
GROUP BY target_build_id;

UPDATE target_builds AS tb, start_times AS st
SET tb.start_time = st.start_time
WHERE tb.id = st.id;
DROP TEMPORARY TABLE start_times;

ALTER TABLE results
ADD COLUMN target_build_id INT,
ADD FOREIGN KEY (target_build_id) REFERENCES target_builds(id);

UPDATE results AS tr, test_run AS runs
SET tr.target_build_id = runs.target_build_id
WHERE tr.id = runs.id;
