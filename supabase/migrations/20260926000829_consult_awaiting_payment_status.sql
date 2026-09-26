-- New on-demand flow: the patient picks a doctor, the doctor is reserved while
-- the patient pays, then the consultation starts. Enum value added on its own
-- because it can't be used in the same transaction that adds it.
alter type consultation_status add value if not exists 'awaiting_payment';
