import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'stick_scene.dart';

/// Practices you do, tips you keep in mind, guides you read.
enum CareKind { practice, tip, guide }

extension CareKindLabel on CareKind {
  String get label => switch (this) {
    CareKind.practice => 'Practices',
    CareKind.tip => 'Tips',
    CareKind.guide => 'Guides',
  };

  /// "5 practices", "1 tip", "4 sections".
  String count(int n) => switch (this) {
    CareKind.practice => '$n practice${n == 1 ? '' : 's'}',
    CareKind.tip => '$n tip${n == 1 ? '' : 's'}',
    CareKind.guide => '$n section${n == 1 ? '' : 's'}',
  };
}

/// Guided breathing: seconds in, held, out, held again; how many rounds.
class BreathPattern {
  const BreathPattern({
    required this.inhale,
    required this.exhale,
    this.hold = 0,
    this.holdAfter = 0,
    this.rounds = 6,
  });

  final int inhale;
  final int hold;
  final int exhale;
  final int holdAfter;
  final int rounds;

  int get roundSeconds => inhale + hold + exhale + holdAfter;
}

/// One practice (or tip, or guide section): a few short steps.
class CareItem {
  const CareItem({
    required this.id,
    required this.title,
    required this.minutes,
    required this.why,
    required this.steps,
    this.breathing,
    this.scenes,
    this.opening,
    this.doneScene = StickSceneKind.celebrate,
  });

  final String id;
  final String title;
  final int minutes;

  /// One line on why it helps.
  final String why;
  final List<String> steps;

  /// Set for breathing practices: a breathing circle leads it.
  final BreathPattern? breathing;

  /// An animated scene for each step (same length as [steps]), shown above
  /// the words.
  final List<StickSceneKind>? scenes;

  /// How she is as the practice opens (she moves from this into the first
  /// step's scene); and how she ends up when it's done.
  final StickSceneKind? opening;
  final StickSceneKind doneScene;
}

/// A group of practices, like "Healthy sleep".
class CareTopic {
  const CareTopic({
    required this.id,
    required this.title,
    required this.kind,
    required this.icon,
    required this.color,
    required this.blurb,
    required this.items,
    this.link,
  });

  final String id;
  final String title;
  final CareKind kind;
  final IconData icon;
  final Color color;
  final String blurb;
  final List<CareItem> items;

  /// Somewhere in the app that goes with it: (label, route).
  final (String, String)? link;

  String get countLabel => kind.count(items.length);
}

const _sleep = CareTopic(
  id: 'healthy-sleep',
  title: 'Healthy sleep',
  kind: CareKind.practice,
  icon: LucideIcons.moon,
  color: Color(0xFF7B5CE6),
  blurb: 'Fall asleep easier and wake up rested.',
  items: [
    CareItem(
      id: 'wind-down',
      title: 'Your wind-down hour',
      minutes: 10,
      why: 'A calm last hour tells your body that sleep is coming.',
      steps: [
        'An hour before bed, dim the lights and put the phone on charge '
            'away from the bed.',
        'Do something slow: a warm shower, gentle stretches or a few pages '
            'of a book.',
        'Write down anything on your mind for tomorrow, so you don\'t have '
            'to hold it tonight.',
        'Keep the room cool, dark and quiet.',
        'Go to bed at about the same time every night, weekends too.',
      ],
      opening: StickSceneKind.tiredNod,
      scenes: [
        StickSceneKind.dimLights,
        StickSceneKind.slowTime,
        StickSceneKind.writeDown,
        StickSceneKind.quietRoom,
        StickSceneKind.asleep,
      ],
      doneScene: StickSceneKind.asleep,
    ),
    CareItem(
      id: 'breath-478',
      title: '4-7-8 breathing for sleep',
      minutes: 3,
      why: 'Long, slow breaths out settle a busy body.',
      steps: [
        'Lie on your back and let your arms rest by your sides.',
        'Breathe in quietly through your nose for 4.',
        'Hold for 7.',
        'Breathe out slowly through your mouth for 8.',
      ],
      breathing: BreathPattern(inhale: 4, hold: 7, exhale: 8, rounds: 4),
    ),
    CareItem(
      id: 'body-scan',
      title: 'Body scan in bed',
      minutes: 8,
      why: 'Noticing each part of the body lets tension go.',
      steps: [
        'Lie comfortably and close your eyes.',
        'Notice your toes and feet. Let them feel heavy.',
        'Move up slowly: legs, hips, belly, chest.',
        'Then hands, arms, shoulders and neck. Soften each one.',
        'Finally your face: loosen the jaw, the eyes, the forehead.',
        'If your mind wanders, gently come back to where you were.',
      ],
    ),
    CareItem(
      id: 'screens-off',
      title: 'Screens off, lights low',
      minutes: 2,
      why: 'Bright screens late at night keep the brain awake.',
      steps: [
        'Pick a time tonight when screens go off, 30 to 60 minutes before '
            'bed.',
        'Turn on night mode if you must use your phone.',
        'Swap the scrolling for music, a book or a chat.',
      ],
    ),
    CareItem(
      id: 'cant-sleep',
      title: 'When you can\'t fall asleep',
      minutes: 5,
      why: 'Lying awake and worrying makes sleep harder.',
      steps: [
        'If you\'re still awake after about 20 minutes, get up.',
        'Go somewhere dim and do something quiet until you feel sleepy.',
        'Avoid the clock: checking the time adds pressure.',
        'Go back to bed only when sleepy.',
        'If poor sleep goes on for weeks, talk to a doctor.',
      ],
    ),
  ],
);

const _eating = CareTopic(
  id: 'mindful-eating',
  title: 'Mindful eating',
  kind: CareKind.practice,
  icon: LucideIcons.coffee,
  color: Color(0xFFE85D9A),
  blurb: 'Enjoy your food and notice when you\'ve had enough.',
  items: [
    CareItem(
      id: 'first-bites',
      title: 'The first three bites',
      minutes: 3,
      why: 'Slowing down at the start sets the pace for the whole meal.',
      steps: [
        'Before you eat, look at your food for a moment.',
        'Take the first bite slowly. Notice the taste and the texture.',
        'Put your spoon or fork down between the first three bites.',
        'Then eat the rest at that calmer pace.',
      ],
    ),
    CareItem(
      id: 'hunger-check',
      title: 'Hunger check',
      minutes: 1,
      why: 'We often eat from boredom or stress, not hunger.',
      steps: [
        'Before eating, ask: how hungry am I, from 1 to 10?',
        'Below 4? Try a glass of water and wait 10 minutes.',
        'Halfway through the meal, check again.',
        'Stop at comfortably full, not stuffed.',
      ],
    ),
    CareItem(
      id: 'no-screens-meal',
      title: 'One meal without screens',
      minutes: 15,
      why: 'Eating while watching makes it easy to overeat.',
      steps: [
        'Choose one meal today to eat away from the TV and phone.',
        'Sit at a table, with others if you can.',
        'Talk, taste and take your time.',
      ],
    ),
    CareItem(
      id: 'water-first',
      title: 'Water before you eat',
      minutes: 1,
      why: 'Thirst can feel like hunger.',
      steps: [
        'Drink a glass of water before each meal.',
        'Keep water, not sugary drinks, on the table.',
      ],
    ),
  ],
);

const _mood = CareTopic(
  id: 'good-mood',
  title: 'Good mood',
  kind: CareKind.practice,
  icon: LucideIcons.sun,
  color: Color(0xFFF29A38),
  blurb: 'Small things that lift your day.',
  items: [
    CareItem(
      id: 'three-good',
      title: 'Three good things',
      minutes: 3,
      why: 'Noticing the good trains the mind to find more of it.',
      steps: [
        'Think back over today.',
        'Name three things that went well, even small ones: a kind word, a '
            'good cup of tea.',
        'For each, ask: why did it go well?',
        'Try it every evening this week.',
      ],
      // The rain clears as she finds her three good things.
      opening: StickSceneKind.sadRain,
      scenes: [
        StickSceneKind.thinkBack,
        StickSceneKind.threeThings,
        StickSceneKind.askWhy,
        StickSceneKind.everyEvening,
      ],
    ),
    CareItem(
      id: 'morning-light',
      title: 'Get some morning light',
      minutes: 10,
      why: 'Daylight early in the day lifts mood and helps sleep at night.',
      steps: [
        'Within an hour of waking, step outside.',
        'Spend 10 minutes in daylight: a short walk, or tea by the door.',
        'No sunglasses needed for this, but never look at the sun.',
      ],
    ),
    CareItem(
      id: 'move-10',
      title: 'Move for 10 minutes',
      minutes: 10,
      why: 'Even a short walk releases feel-good chemicals.',
      steps: [
        'Put on comfortable shoes.',
        'Walk briskly for 5 minutes in one direction, then turn back.',
        'Notice three things you see along the way.',
      ],
    ),
    CareItem(
      id: 'reach-out',
      title: 'Reach out to someone',
      minutes: 5,
      why: 'Connection is one of the strongest mood boosters.',
      steps: [
        'Think of someone you haven\'t spoken to in a while.',
        'Send them a message or give them a call.',
        'Ask how they are, and listen.',
      ],
      opening: StickSceneKind.celebrate,
      scenes: [
        StickSceneKind.reachThink,
        StickSceneKind.reachMessage,
        StickSceneKind.reachListen,
      ],
    ),
  ],
);

const _emotions = CareTopic(
  id: 'regulate-emotions',
  title: 'Regulate your emotions',
  kind: CareKind.practice,
  icon: LucideIcons.sparkles,
  color: Color(0xFFF6C443),
  blurb: 'Ways to steady yourself when feelings run high.',
  items: [
    CareItem(
      id: 'name-it',
      title: 'Name it to tame it',
      minutes: 2,
      why: 'Putting a feeling into words makes it less intense.',
      steps: [
        'Pause and notice what you feel in your body.',
        'Name the feeling in one word: angry, hurt, worried, tired.',
        'Say it quietly: "I\'m feeling ___ right now."',
        'Remind yourself: feelings rise and fall. This one will too.',
      ],
      opening: StickSceneKind.moodySwing,
      scenes: [
        StickSceneKind.noticeBody,
        StickSceneKind.nameFeeling,
        StickSceneKind.sayIt,
        StickSceneKind.riseAndFall,
      ],
    ),
    CareItem(
      id: 'cool-down',
      title: 'Pause and cool down',
      minutes: 3,
      why: 'A short pause stops you acting on the first wave of anger.',
      steps: [
        'Stop. Don\'t reply or act yet.',
        'Take a step back, or leave the room if you need to.',
        'Breathe out slowly, longer than you breathe in, five times.',
        'Ask: what do I actually need right now?',
        'Come back when your body feels calmer.',
      ],
      opening: StickSceneKind.angryStomp,
      scenes: [
        StickSceneKind.stopNow,
        StickSceneKind.stepBack,
        StickSceneKind.breatheOut,
        StickSceneKind.whatINeed,
        StickSceneKind.comeBack,
      ],
    ),
    CareItem(
      id: 'box-breathing',
      title: 'Box breathing',
      minutes: 3,
      why: 'Even counts give a racing mind something steady to follow.',
      steps: [
        'Sit upright with your feet flat on the floor.',
        'Breathe in for 4, hold for 4.',
        'Breathe out for 4, hold for 4.',
      ],
      breathing: BreathPattern(inhale: 4, hold: 4, exhale: 4, holdAfter: 4),
    ),
    CareItem(
      id: 'grounding',
      title: '5-4-3-2-1 grounding',
      minutes: 3,
      why: 'Your senses pull you back into the present moment.',
      steps: [
        'Look around and name 5 things you can see.',
        'Notice 4 things you can feel: your feet, the chair, your clothes.',
        'Listen for 3 things you can hear.',
        'Find 2 things you can smell.',
        'Name 1 thing you can taste.',
      ],
    ),
    CareItem(
      id: 'write-it',
      title: 'Write it out',
      minutes: 5,
      why: 'Getting thoughts onto paper takes them out of your head.',
      steps: [
        'Take a paper or your notes app.',
        'Write whatever you\'re feeling for 5 minutes. Don\'t edit.',
        'Read it back. Is there one small thing you can do about it?',
      ],
    ),
  ],
);

const _calm = CareTopic(
  id: 'keep-calm',
  title: 'Keep calm',
  kind: CareKind.practice,
  icon: LucideIcons.flower2,
  color: Color(0xFF9B6BE8),
  blurb: 'Quick ways to ease worry and tension.',
  items: [
    CareItem(
      id: 'calm-breathing',
      title: 'Calm breathing',
      minutes: 2,
      why: 'Breathing out longer than in slows the heart down.',
      steps: [
        'Sit or lie comfortably. Drop your shoulders.',
        'Breathe in through your nose for 4.',
        'Breathe out gently through your mouth for 6.',
      ],
      breathing: BreathPattern(inhale: 4, exhale: 6, rounds: 8),
    ),
    CareItem(
      id: 'shoulders',
      title: 'Let your shoulders go',
      minutes: 4,
      why:
          'Tensing then relaxing muscles shows the body what calm feels '
          'like.',
      steps: [
        'Lift your shoulders up to your ears. Hold for 5.',
        'Let them drop. Notice the difference.',
        'Make fists, hold for 5, then let your hands open.',
        'Scrunch your face, hold, then soften it.',
        'Finish with three slow breaths.',
      ],
    ),
    CareItem(
      id: 'worry-time',
      title: 'Worry time',
      minutes: 10,
      why: 'Giving worries a set time stops them taking the whole day.',
      steps: [
        'When a worry comes up, jot it down and tell yourself: later.',
        'Set 10 minutes in the early evening as worry time.',
        'Go through the list. For each: can I do something about it?',
        'If yes, plan one step. If not, let it go for today.',
      ],
    ),
    CareItem(
      id: 'hand-on-heart',
      title: 'Hand on heart',
      minutes: 1,
      why: 'Warm, gentle touch is soothing, even from yourself.',
      steps: [
        'Place a hand on your chest.',
        'Feel the warmth and your breath under your hand.',
        'Say something kind to yourself, as you would to a friend.',
      ],
    ),
  ],
);

const _reading = CareTopic(
  id: 'relax-reading',
  title: 'Relax reading',
  kind: CareKind.practice,
  icon: LucideIcons.bookOpen,
  color: Color(0xFF2FB277),
  blurb: 'A few quiet pages to rest the mind.',
  items: [
    CareItem(
      id: 'ten-pages',
      title: 'Ten quiet pages',
      minutes: 15,
      why: 'Reading slows the mind more than scrolling does.',
      steps: [
        'Pick something you enjoy: a novel, a magazine, scripture.',
        'Find a comfortable spot with good light.',
        'Read ten pages without checking your phone.',
      ],
    ),
    CareItem(
      id: 'read-aloud',
      title: 'Read aloud to someone',
      minutes: 10,
      why: 'Sharing a story connects you and calms you both.',
      steps: [
        'Choose a short story or a chapter.',
        'Read it aloud to a child, a partner or a parent.',
        'Talk about it afterwards.',
      ],
    ),
    CareItem(
      id: 'swap-scroll',
      title: 'Swap scrolling for a story',
      minutes: 10,
      why: 'Endless feeds keep the brain busy; a story lets it rest.',
      steps: [
        'Next time you reach for social media, open a book instead.',
        'Keep a book by your bed or in your bag to make it easy.',
      ],
    ),
  ],
);

const _time = CareTopic(
  id: 'time-balance',
  title: 'Time balance',
  kind: CareKind.practice,
  icon: LucideIcons.clock,
  color: Color(0xFF3E8EF7),
  blurb: 'Make room for rest as well as work.',
  items: [
    CareItem(
      id: 'three-things',
      title: 'Plan three things',
      minutes: 3,
      why: 'A short list feels doable; a long one feels heavy.',
      steps: [
        'In the morning, write the three things that matter most today.',
        'Do the hardest one first, if you can.',
        'Anything else is a bonus.',
      ],
    ),
    CareItem(
      id: 'real-breaks',
      title: 'Take real breaks',
      minutes: 10,
      why: 'Short breaks keep your energy up all day.',
      steps: [
        'After about 50 minutes of work, stop for 10.',
        'Stand up, stretch, drink water, look into the distance.',
        'Leave the screen behind for the break.',
      ],
    ),
    CareItem(
      id: 'say-no',
      title: 'Say no kindly',
      minutes: 2,
      why: 'Every yes uses time you might need for yourself.',
      steps: [
        'Before agreeing, say: "Let me check and get back to you."',
        'Ask: do I have the time and energy for this?',
        'If not: "Thank you for asking. I can\'t this time."',
      ],
    ),
  ],
);

const _move = CareTopic(
  id: 'move-your-body',
  title: 'Move your body',
  kind: CareKind.practice,
  icon: LucideIcons.footprints,
  color: Color(0xFF0EA5A8),
  blurb: 'Gentle movement for a stronger body and a clearer head.',
  items: [
    CareItem(
      id: 'walk-10',
      title: 'A 10-minute walk',
      minutes: 10,
      why: 'Walking after meals helps blood sugar and digestion.',
      steps: [
        'After a meal, take a relaxed 10-minute walk.',
        'Swing your arms and breathe deeply.',
        'Build up to 30 minutes most days.',
      ],
      opening: StickSceneKind.calmSit,
      scenes: [
        StickSceneKind.walkStart,
        StickSceneKind.walkBreathe,
        StickSceneKind.walkWeek,
      ],
    ),
    CareItem(
      id: 'desk-stretch',
      title: 'Desk stretches',
      minutes: 5,
      why: 'Sitting for hours stiffens the neck, back and hips.',
      steps: [
        'Roll your shoulders back five times.',
        'Tilt your head gently to each side and hold for 10.',
        'Stand and reach your arms up, then fold forward softly.',
        'Twist gently to each side in your chair.',
      ],
    ),
    CareItem(
      id: 'one-song',
      title: 'Dance to one song',
      minutes: 4,
      why: 'Music and movement together lift mood fast.',
      steps: [
        'Put on a song you love.',
        'Move however you like until it ends.',
      ],
    ),
  ],
);

const _water = CareTopic(
  id: 'water',
  title: 'Drink enough water',
  kind: CareKind.tip,
  icon: LucideIcons.droplets,
  color: Color(0xFF2EA3E8),
  blurb: 'Simple ways to stay hydrated through the day.',
  items: [
    CareItem(
      id: 'water-bottle',
      title: 'Keep a bottle with you',
      minutes: 1,
      why: 'If it\'s in reach, you\'ll drink it.',
      steps: ['Fill a bottle in the morning and keep it where you can see it.'],
    ),
    CareItem(
      id: 'water-pee',
      title: 'Check the colour',
      minutes: 1,
      why: 'Pale yellow urine usually means you\'re drinking enough.',
      steps: ['Dark yellow? Drink a glass or two more today.'],
    ),
    CareItem(
      id: 'water-heat',
      title: 'More on hot days',
      minutes: 1,
      why: 'You lose more water in the heat and when active.',
      steps: [
        'Drink extra on hot days, when exercising, or with fever or '
            'diarrhoea.',
      ],
    ),
    CareItem(
      id: 'water-sugar',
      title: 'Water over sugary drinks',
      minutes: 1,
      why: 'Sodas and juices add sugar without filling you up.',
      steps: ['Add a slice of lemon or cucumber if plain water is boring.'],
    ),
  ],
);

const _screens = CareTopic(
  id: 'screen-breaks',
  title: 'Screen breaks',
  kind: CareKind.tip,
  icon: LucideIcons.monitorSmartphone,
  color: Color(0xFF5B6CF0),
  blurb: 'Rest your eyes and your mind.',
  items: [
    CareItem(
      id: 'twenty',
      title: 'The 20-20-20 rule',
      minutes: 1,
      why: 'Your eyes tire from focusing close up for long.',
      steps: [
        'Every 20 minutes, look at something 20 feet away for 20 seconds.',
      ],
    ),
    CareItem(
      id: 'phone-free',
      title: 'Phone-free first hour',
      minutes: 1,
      why: 'Starting the day on your own terms feels calmer.',
      steps: ['Try not to check your phone for the first hour after waking.'],
    ),
    CareItem(
      id: 'notifications',
      title: 'Fewer notifications',
      minutes: 2,
      why: 'Every ping pulls your attention away.',
      steps: ['Turn off notifications for apps that aren\'t important.'],
    ),
  ],
);

const _plate = CareTopic(
  id: 'balanced-plate',
  title: 'A balanced plate',
  kind: CareKind.tip,
  icon: LucideIcons.salad,
  color: Color(0xFF3FAF5A),
  blurb: 'Everyday food that looks after you.',
  items: [
    CareItem(
      id: 'half-veg',
      title: 'Half the plate vegetables',
      minutes: 1,
      why: 'Sukuma, cabbage and other greens fill you with few calories.',
      steps: [
        'Fill half your plate with vegetables, a quarter with ugali, '
            'rice or chapati, and a quarter with beans, fish, eggs or meat.',
      ],
    ),
    CareItem(
      id: 'less-salt',
      title: 'Go easy on salt',
      minutes: 1,
      why: 'Too much salt raises blood pressure.',
      steps: [
        'Taste before adding salt, and cut down on crisps and stock '
            'cubes.',
      ],
    ),
    CareItem(
      id: 'fruit-snack',
      title: 'Fruit for snacks',
      minutes: 1,
      why: 'Fruit gives sweetness with fibre and vitamins.',
      steps: ['Swap biscuits or mandazi for a banana, orange or mango.'],
    ),
    CareItem(
      id: 'whole-grains',
      title: 'Choose whole grains',
      minutes: 1,
      why: 'They keep you full longer and help steady blood sugar.',
      steps: [
        'Try brown ugali (whole maize flour), brown rice or whole '
            'wheat bread.',
      ],
    ),
  ],
);

const _stress = CareTopic(
  id: 'managing-stress',
  title: 'Managing stress',
  kind: CareKind.guide,
  icon: LucideIcons.brain,
  color: Color(0xFFD9577B),
  blurb: 'Understand stress and what helps.',
  items: [
    CareItem(
      id: 'stress-what',
      title: 'What stress does',
      minutes: 2,
      why: 'Stress is the body getting ready to face a challenge.',
      steps: [
        'A little stress helps you focus. Too much, for too long, wears '
            'you down.',
        'Signs include poor sleep, headaches, a tight chest, irritability '
            'and trouble concentrating.',
      ],
    ),
    CareItem(
      id: 'stress-daily',
      title: 'Daily habits that help',
      minutes: 2,
      why: 'Small, steady habits build resilience.',
      steps: [
        'Sleep 7 to 9 hours.',
        'Move your body most days.',
        'Eat regular meals and limit alcohol and caffeine.',
        'Spend time with people who lift you up.',
      ],
    ),
    CareItem(
      id: 'stress-moment',
      title: 'In a stressful moment',
      minutes: 2,
      why: 'Calm the body first; the mind follows.',
      steps: [
        'Breathe out slowly, longer than you breathe in.',
        'Step away for a few minutes if you can.',
        'Break the problem into one small next step.',
      ],
    ),
    CareItem(
      id: 'stress-help',
      title: 'When to get help',
      minutes: 1,
      why: 'You don\'t have to manage it alone.',
      steps: [
        'If stress affects your sleep, work or relationships for more than '
            'two weeks, talk to a doctor.',
        'If you ever feel unsafe or think about harming yourself, call 999 '
            'or 1199 now.',
      ],
    ),
  ],
);

const _bp = CareTopic(
  id: 'blood-pressure',
  title: 'Living with high blood pressure',
  kind: CareKind.guide,
  icon: LucideIcons.heartPulse,
  color: Color(0xFFE0433D),
  blurb: 'Everyday steps that bring your numbers down.',
  link: ('Log your blood pressure', '/patient/readings?kind=bp'),
  items: [
    CareItem(
      id: 'bp-numbers',
      title: 'Know your numbers',
      minutes: 2,
      why: 'High blood pressure often has no symptoms.',
      steps: [
        'Below 120/80 is healthy. 140/90 or more on repeat checks is high.',
        'Check at the same time of day, seated, after 5 minutes of rest.',
        'Log your readings in GoDoctor so your doctor can see the trend.',
      ],
    ),
    CareItem(
      id: 'bp-food',
      title: 'Food that helps',
      minutes: 2,
      why: 'Less salt and more vegetables lower blood pressure.',
      steps: [
        'Cut down on salt, crisps, processed meats and stock cubes.',
        'Eat plenty of vegetables, fruit, beans and whole grains.',
        'Limit alcohol.',
      ],
    ),
    CareItem(
      id: 'bp-move',
      title: 'Move and rest',
      minutes: 2,
      why: 'Regular activity and good sleep strengthen the heart.',
      steps: [
        'Aim for 30 minutes of brisk walking most days.',
        'Keep a healthy weight, and don\'t smoke.',
        'Sleep 7 to 9 hours.',
      ],
    ),
    CareItem(
      id: 'bp-meds',
      title: 'Your medicines',
      minutes: 1,
      why: 'Medicines work only when taken every day.',
      steps: [
        'Take them at the same time daily. Set a reminder in GoDoctor.',
        'Don\'t stop them because you feel fine; talk to your doctor first.',
      ],
    ),
    CareItem(
      id: 'bp-urgent',
      title: 'When it\'s urgent',
      minutes: 1,
      why: 'Very high blood pressure can be an emergency.',
      steps: [
        '180/120 or higher with chest pain, a severe headache, weakness or '
            'trouble speaking: call 999 now.',
      ],
    ),
  ],
);

const _sugar = CareTopic(
  id: 'blood-sugar',
  title: 'Blood sugar basics',
  kind: CareKind.guide,
  icon: LucideIcons.droplet,
  color: Color(0xFFE9804C),
  blurb: 'Keeping your sugar steady, day to day.',
  link: ('Log your blood sugar', '/patient/readings?kind=sugar'),
  items: [
    CareItem(
      id: 'sugar-numbers',
      title: 'Healthy ranges',
      minutes: 2,
      why: 'Knowing your range helps you spot a problem early.',
      steps: [
        'Fasting: 3.9 to 5.5 mmol/L is normal.',
        'Two hours after a meal: under 7.8 mmol/L is normal.',
        'Log readings in GoDoctor to see your trend.',
      ],
    ),
    CareItem(
      id: 'sugar-food',
      title: 'Meals that keep it steady',
      minutes: 2,
      why: 'Fibre and protein slow down how fast sugar rises.',
      steps: [
        'Eat regular meals; don\'t skip breakfast.',
        'Fill half the plate with vegetables.',
        'Swap sugary drinks for water.',
      ],
    ),
    CareItem(
      id: 'sugar-low',
      title: 'If your sugar goes low',
      minutes: 1,
      why: 'Low sugar (below 3.9) needs quick action.',
      steps: [
        'Signs: shaking, sweating, confusion, a fast heartbeat.',
        'Take something sugary: juice, glucose or sweets. Check again '
            'after 15 minutes.',
        'If they can\'t swallow or are passing out, call 999.',
      ],
    ),
    CareItem(
      id: 'sugar-feet',
      title: 'Look after your feet',
      minutes: 1,
      why: 'High sugar can reduce feeling in the feet.',
      steps: [
        'Check your feet daily for cuts or sores.',
        'Wear comfortable shoes, and see a doctor about any wound that '
            'doesn\'t heal.',
      ],
    ),
  ],
);

/// Everything, in the order it's shown.
const kCareTopics = <CareTopic>[
  _sleep,
  _eating,
  _mood,
  _emotions,
  _calm,
  _reading,
  _time,
  _move,
  _water,
  _screens,
  _plate,
  _stress,
  _bp,
  _sugar,
];

CareTopic? careTopic(String id) =>
    kCareTopics.where((t) => t.id == id).firstOrNull;

/// The topic an item belongs to, and the item.
(CareTopic, CareItem)? careItem(String id) {
  for (final t in kCareTopics) {
    for (final i in t.items) {
      if (i.id == id) return (t, i);
    }
  }
  return null;
}

/// The practice to suggest on Home right now (null: not today). A feeling
/// picks it when one fits; otherwise the time of day, and only every other
/// day so it stays a nice surprise.
(CareTopic, CareItem)? suggestPractice(DateTime now, {String? mood}) {
  final byMood = switch (mood) {
    'anxious' => 'calm-breathing',
    'angry' => 'cool-down',
    'moody' => 'name-it',
    'tired' => 'wind-down',
    'sad' => 'three-good',
    'calm' || 'happy' => 'reach-out',
    _ => null,
  };
  if (byMood != null) return careItem(byMood);
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  if (now.hour >= 20 || now.hour < 4) return careItem('wind-down');
  if (dayOfYear.isOdd) return null;
  if (now.hour < 10) return careItem('morning-light');
  if (now.hour < 14) return careItem('real-breaks');
  if (now.hour < 17) return careItem('desk-stretch');
  return careItem('walk-10');
}
