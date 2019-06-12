--
-- FSM design and graph v1
--

CREATE TYPE order_state AS ENUM (
  'start',
  'awaiting_payment',
  'awaiting_shipment',
  'awaiting_refund',
  'shipped',
  'canceled',
  'error'
);

CREATE TYPE order_event AS ENUM (
  'create',
  'pay',
  'ship',
  'refund',
  'cancel'
);

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE order_fsm_version_status AS ENUM (
  'live',
  'deprecated',
  'obsolete'
);

CREATE TABLE order_fsm_versions(
  version integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  status  order_fsm_version_status NOT NULL DEFAULT 'live'
);

CREATE FUNCTION order_fsm_last_version()
RETURNS integer LANGUAGE sql AS $$
SELECT version FROM order_fsm_versions ORDER BY version DESC LIMIT 1;
$$;

CREATE TABLE order_events (
  id       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id uuid        NOT NULL DEFAULT uuid_generate_v4(),
  event    order_event NOT NULL DEFAULT 'create',
  version  integer     NOT NULL DEFAULT order_fsm_last_version(),
  time     timestamp   NOT NULL DEFAULT now(),
  FOREIGN KEY (version) REFERENCES order_fsm_versions(version)
);

CREATE TABLE order_events_transitions (
  state      order_state NOT NULL,
  event      order_event NOT NULL,
  version    integer     NOT NULL DEFAULT order_fsm_last_version(),
  next_state order_state NOT NULL,
  PRIMARY KEY (state, event, version, next_state),
  FOREIGN KEY (version) REFERENCES order_fsm_versions(version)
);

INSERT INTO order_fsm_versions (status) VALUES ('live') RETURNING *;

INSERT INTO order_events_transitions (state, event, next_state) VALUES
  ('start',             'create', 'awaiting_payment' ),
  ('awaiting_payment',  'pay',    'awaiting_shipment'),
  ('awaiting_payment',  'cancel', 'canceled'         ),
  ('awaiting_shipment', 'cancel', 'awaiting_refund'  ),
  ('awaiting_shipment', 'ship',   'shipped'          ),
  ('awaiting_refund',   'refund', 'canceled'         );

CREATE FUNCTION order_events_transition(_state order_state, _event order_event, _version integer DEFAULT order_fsm_last_version())
RETURNS order_state LANGUAGE sql AS $$
SELECT COALESCE(
  (SELECT next_state
   FROM order_events_transitions
   WHERE state=_state AND event=_event AND version=_version),
  'error'::order_state);
$$;

SELECT state, event, order_events_transition(state::order_state, event::order_event)
FROM (VALUES
  ('start',            'create'),
  ('awaiting_payment', 'pay'   ),
  ('awaiting_payment', 'cancel'),
  ('awaiting_payment', 'ship'  )
) AS examples(state, event);

CREATE AGGREGATE order_events_fsm(order_event, integer) (
  SFUNC = order_events_transition,
  STYPE = order_state,
  INITCOND = 'start'
);

CREATE FUNCTION order_events_trigger_func() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  next_state order_state;
  transition_status order_fsm_version_status;
BEGIN
  SELECT status FROM order_fsm_versions WHERE version=new.version INTO transition_status;
  IF transition_status = 'deprecated'::order_fsm_version_status THEN
    RAISE NOTICE 'version % is deprecated', new.version;
  END IF;
  IF transition_status = 'obsolete'::order_fsm_version_status THEN
    RAISE EXCEPTION 'version % is obsolete', new.version;
  END IF;

  SELECT order_events_fsm(event, version ORDER BY id)
  FROM (
    SELECT id, event, version FROM order_events WHERE order_id = new.order_id
    UNION
    SELECT new.id, new.event, new.version
  ) s
  INTO next_state;

  IF next_state = 'error'::order_state THEN
    RAISE EXCEPTION 'invalid order event';
  END IF;

  RETURN new;
END
$$;

CREATE TRIGGER order_events_trigger BEFORE INSERT ON order_events
FOR EACH ROW EXECUTE PROCEDURE order_events_trigger_func();

INSERT INTO order_events (order_id, event, time) VALUES
  ('0685d9d1-f318-41bf-8fcd-566689e88893', 'create', '2017-07-23 00:00:00'),
  ('0685d9d1-f318-41bf-8fcd-566689e88893', 'pay',    '2017-07-23 12:00:00'),
  ('0685d9d1-f318-41bf-8fcd-566689e88893', 'ship',   '2017-07-24 00:00:00'),

  ('57bc0c16-929e-46a2-8bba-2fd5381105bd', 'create', '2017-07-23 00:00:00'),
  ('57bc0c16-929e-46a2-8bba-2fd5381105bd', 'cancel', '2017-07-24 00:00:00'),

  ('ea21b149-247e-49fe-a8a3-53d161a03d24', 'create', '2017-07-23 00:00:00'),
  ('ea21b149-247e-49fe-a8a3-53d161a03d24', 'pay',    '2017-07-24 00:00:00'),
  ('ea21b149-247e-49fe-a8a3-53d161a03d24', 'cancel', '2017-07-25 00:00:00'),
  ('ea21b149-247e-49fe-a8a3-53d161a03d24', 'refund', '2017-07-26 00:00:00');

SELECT order_id, time, version, order_events_fsm(event, version) OVER (PARTITION BY order_id ORDER BY id)
FROM order_events ORDER BY order_id ASC;

---
--- Graph v2
---

ALTER TYPE order_event ADD VALUE 'approve';
ALTER TYPE order_state ADD VALUE 'awaiting_approval';

INSERT INTO order_fsm_versions (status) VALUES ('live') RETURNING *;
UPDATE order_fsm_versions SET status='deprecated' WHERE version = 1;

INSERT INTO order_events_transitions (state, event, next_state) VALUES
  ('start',             'create',  'awaiting_approval'),
  ('awaiting_approval', 'approve', 'awaiting_payment' ),
  ('awaiting_payment',  'pay',     'awaiting_shipment'),
  ('awaiting_payment',  'cancel',  'canceled'         ),
  ('awaiting_shipment', 'cancel',  'awaiting_refund'  ),
  ('awaiting_shipment', 'ship',    'shipped'          ),
  ('awaiting_refund',   'refund',  'canceled'         );

-- The following will fail
INSERT INTO order_events (order_id, event, time) VALUES
  ('3545339e-1ce2-4b5d-b897-39c537bdbb71', 'create', '2017-07-23 00:00:00'),
  ('3545339e-1ce2-4b5d-b897-39c537bdbb71', 'pay',    '2017-07-23 12:00:00');

-- The following will succeed but with a notice
INSERT INTO order_events (order_id, event, time, version) VALUES
  ('3545339e-1ce2-4b5d-b897-39c537bdbb71', 'create', '2017-07-23 00:00:00', 1),
  ('3545339e-1ce2-4b5d-b897-39c537bdbb71', 'pay',    '2017-07-23 12:00:00', 1);

INSERT INTO order_events (order_id, event, time, version) VALUES
  ('0d687d74-bab3-4c76-beed-0f55ec8a3af2', 'create',  '2017-07-23 00:00:00', 2),
  ('0d687d74-bab3-4c76-beed-0f55ec8a3af2', 'approve', '2017-07-23 00:00:00', 2),
  ('0d687d74-bab3-4c76-beed-0f55ec8a3af2', 'pay',     '2017-07-23 12:00:00', 2);

SELECT order_id, time, version, order_events_fsm(event, version) OVER (PARTITION BY order_id ORDER BY id)
FROM order_events ORDER BY order_id ASC;

