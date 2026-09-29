-- More ways to say how you feel: happy, calm, okay, tired, moody, sad,
-- anxious, angry, under the weather. The first five-mood set stays valid
-- for check-ins already saved.
alter table public.mood_checkins
  drop constraint if exists mood_checkins_mood_check;

alter table public.mood_checkins
  add constraint mood_checkins_mood_check check (
    mood in (
      'happy', 'calm', 'okay', 'tired', 'moody', 'sad', 'anxious', 'angry',
      'under_the_weather',
      -- earlier set
      'great', 'good', 'low', 'unwell'
    )
  );
