CREATE TABLE test_cases (
	id INT NOT NULL AUTO_INCREMENT,
	name VARCHAR(255) NOT NULL,
	PRIMARY KEY (id)
);

ALTER TABLE results
ADD COLUMN test_case_id INT,
ADD FOREIGN KEY (test_case_id) REFERENCES test_cases(id);

INSERT INTO test_cases (name)
SELECT DISTINCT test
FROM results;

UPDATE results AS tr, test_cases AS tc
SET tr.test_case_id = tc.id
WHERE tr.test = tc.name;

CREATE INDEX test_cases_name_index
ON test_cases(name);

CREATE INDEX target_builds_start_time_index
ON target_builds(start_time);

CREATE INDEX target_builds_maxscale_source_index
ON target_builds(maxscale_source);

CREATE INDEX target_builds_box_index
ON target_builds(box);

CREATE INDEX target_builds_maxscale_source_and_box_index
ON target_builds(maxscale_source, box);
