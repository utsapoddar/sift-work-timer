import 'package:flutter/material.dart';

class Milestone {
  final int day;
  final String title;
  final String icon;
  final Color color;
  final String sub;
  final String science;
  final String rarity;
  final String commitmentText;

  const Milestone({
    required this.day,
    required this.title,
    required this.icon,
    required this.color,
    required this.sub,
    required this.science,
    required this.rarity,
    required this.commitmentText,
  });
}

const milestones = [
  Milestone(
    day: 1, title: 'First Step', icon: '🌱',
    color: Color(0xFF34D399), rarity: '100%',
    sub: 'You showed up. That alone puts you ahead of everyone who didn\'t.',
    science: 'Starting is the hardest part — the prefrontal cortex burns the most energy on unfamiliar tasks. Day 1 has the highest dropout rate across all habit-tracking research.',
    commitmentText: 'You started. That\'s the whole move. Show up again tomorrow.',
  ),
  Milestone(
    day: 3, title: 'Momentum', icon: '🚀',
    color: Color(0xFF22D3EE), rarity: '~62%',
    sub: 'Three consecutive days activates your brain\'s pattern-detection system.',
    science: 'The Zeigarnik Effect kicks in here — your brain remembers incomplete sequences more vividly than completed ones, creating a persistent mental pull to continue.',
    commitmentText: 'Three days tells your brain this is a pattern. Keep feeding it.',
  ),
  Milestone(
    day: 7, title: 'Streak Ignited', icon: '🔥',
    color: Color(0xFFF97316), rarity: '~45%',
    sub: 'One full week. Habit-tracking research shows 7-day streakers are 3.6x more likely to reach their goal.',
    science: 'Research from behavioral economists found people will expend 40% more effort to maintain an active streak than to achieve the same behavior without one. Loss aversion has locked in.',
    commitmentText: 'Loss aversion is now working for you. Your brain actively fights to protect what you\'ve built. Don\'t waste it.',
  ),
  Milestone(
    day: 14, title: 'Habit Seed Planted', icon: '🌿',
    color: Color(0xFFA78BFA), rarity: '~30%',
    sub: 'Two solid weeks. Your basal ganglia is starting to encode this as routine.',
    science: 'The simplest habits can become automatic in as few as 18 days. You\'re approaching that threshold — the effort required to show up is already shrinking.',
    commitmentText: 'Two weeks in, and your basal ganglia is beginning to take over. It gets easier from here. Trust the process.',
  ),
  Milestone(
    day: 30, title: 'One Month Strong', icon: '💎',
    color: Color(0xFF3B82F6), rarity: '~18%',
    sub: 'You\'ve outlasted the vast majority. This is exactly where most people stop.',
    science: 'Tracked habits are 2.5x more likely to be maintained than untracked ones. The act of observing your own consistency is itself a reinforcing mechanism.',
    commitmentText: 'Past the wall. Most people quit right here. You didn\'t. Protect it.',
  ),
  Milestone(
    day: 66, title: 'Habit Formed', icon: '🧠',
    color: Color(0xFF8B5CF6), rarity: '~8%',
    sub: 'The median point at which behaviors become automatic, per University College London research.',
    science: '96 participants tracked over 84 days at UCL. Median automaticity plateau: 66 days. Range: 18–254 days. Your habit now lives in the basal ganglia, not the prefrontal cortex.',
    commitmentText: 'Your brain has literally rewired itself. This is no longer discipline — it\'s becoming who you are. That shift is permanent.',
  ),
  Milestone(
    day: 100, title: 'Triple Digits', icon: '👑',
    color: Color(0xFFF59E0B), rarity: '~5%',
    sub: 'Complex behaviors require 100+ days to become fully automatic. You\'re there.',
    science: 'Research on 60,000 gym users confirmed deep habits take months, not weeks, to fully form. At this point, the behavior is context-encoded and largely reward-insensitive.',
    commitmentText: 'Triple digits. You\'ve stopped asking whether you\'ll work today. That question is already answered.',
  ),
  Milestone(
    day: 200, title: 'Iron Will', icon: '🛡️',
    color: Color(0xFFEF4444), rarity: '~2.5%',
    sub: 'Motivation is irrelevant at this point. This is identity.',
    science: 'Identity-based habit research shows the shift from "doing" to "being" is the strongest predictor of permanence. You no longer do focused work — you are a focused person.',
    commitmentText: 'You\'re not doing focus sessions anymore. You are a focused person. That\'s a different thing entirely — and it\'s permanent.',
  ),
  Milestone(
    day: 365, title: 'One Year Legend', icon: '🏆',
    color: Color(0xFFEAB308), rarity: '<1.5%',
    sub: 'One full year. The habit is now self-sustaining — missing a day would feel physically wrong.',
    science: 'Streak retention data across major habit apps: fewer than 20% of daily active users reach a 365-day streak. The habit is now part of your identity architecture.',
    commitmentText: 'One year. The gap between you and everyone who started alongside you is now enormous. Keep going.',
  ),
  Milestone(
    day: 500, title: 'Mythic', icon: '🌋',
    color: Color(0xFFDC2626), rarity: '<0.5%',
    sub: 'You have outlasted nearly every person who has ever attempted a daily habit of any kind.',
    science: 'Research on ultra-long streaks found participants at this range report complete automaticity — the behavior has features indistinguishable from brushing teeth. It simply happens.',
    commitmentText: 'There is almost no one left who knows what this feels like. You do.',
  ),
  Milestone(
    day: 1000, title: 'Transcendent', icon: '⭐',
    color: Color(0xFFF97316), rarity: '<0.1%',
    sub: '1,000 consecutive days. Nearly three years of showing up, no matter what.',
    science: 'Behavioral research has barely studied streaks this long because so few people reach them. You are a genuine statistical outlier — and a real one, not a rounding error.',
    commitmentText: '', // special — handled in MilestoneScreen
  ),
];

Milestone? getCurrentMilestone(int streak) {
  Milestone? current;
  for (final m in milestones) {
    if (streak >= m.day) current = m;
  }
  return current;
}

Milestone? getNextMilestone(int streak) {
  for (final m in milestones) {
    if (m.day > streak) return m;
  }
  return null;
}

Milestone? detectNewMilestone(int oldStreak, int newStreak) {
  Milestone? result;
  for (final m in milestones) {
    if (m.day > oldStreak && m.day <= newStreak) result = m;
  }
  return result;
}
