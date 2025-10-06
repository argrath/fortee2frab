#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::UserAgent;
use Mojo::DOM;
use Text::CSV;
use Encode qw(encode_utf8 decode_utf8);

# =========================================================
# 設定
# =========================================================
my @dates = (
    '2025-11-14',
    '2025-11-15',
);

my $base_url = 'https://fortee.jp/yapc-fukuoka-2025/timetable/';
my $output_csv = 'yapc_fukuoka_2025_all_days.csv';

# トラック番号 → トラック名
my %track_name = (
    1 => 'Track A',
    2 => 'Track B',
    3 => 'Track C',
    4 => 'Track D',
);

# fortee 時間換算設定
my $base_hour      = 9;
my $px_per_minute  = 6;

# =========================================================
# CSV 出力準備
# =========================================================
my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
open my $fh, '>', $output_csv or die "Cannot open $output_csv: $!";
$csv->print($fh, [qw(Date Start Duration_minutes Speaker Title Track)]);

# =========================================================
# Webアクセス
# =========================================================
my $ua = Mojo::UserAgent->new;

foreach my $date (@dates) {
    my $url = $base_url . $date;
    print "Fetching $url ...\n";

    my $res = $ua->get($url)->result;
    unless ($res->is_success) {
        warn "❌ Failed to fetch $url: " . $res->code . " " . $res->message;
        next;
    }

    my $dom = Mojo::DOM->new($res->body);

    # 各トークを抽出
    for my $talk ($dom->find('div.proposal-in-timetable')->each) {
        my $style = $talk->attr('style') // '';

        my ($top)    = $style =~ /top:(\d+)px/;
        my ($height) = $style =~ /height:(\d+)px/;
        my ($track_no) = $style =~ /track-(\d+)/;

        # --- 開始時刻 ---
        my $start_time = '';
        if (defined $top) {
            my $minutes_from_base = int($top / $px_per_minute + 0.5);
            my $hour = $base_hour + int($minutes_from_base / 60);
            my $min  = $minutes_from_base % 60;
            $start_time = sprintf("%02d:%02d", $hour, $min);
        }

        # --- 所要時間 ---
        my $duration_min = defined $height ? int($height / $px_per_minute + 0.5) : '';

        # --- タイトル・スピーカー ---
        my $title = $talk->at('div.title') ? $talk->at('div.title')->all_text : '';
        my $speaker = $talk->at('div.speaker-name') ? $talk->at('div.speaker-name')->all_text : '';
        $speaker =~ s/\s+/ /g; # 余分な空白を削除
        $title   =~ s/\s+/ /g; # 余分な空白を削除
        $title   = decode_utf8($title);
        $speaker = decode_utf8($speaker);

        # --- トラック名 ---
        my $track = $track_name{$track_no} || "Track $track_no";

        # --- 出力 ---
        $csv->print($fh, [$date, $start_time, $duration_min, $speaker, $title, $track]);
    }

    print "✅ Parsed $url successfully.\n";
}

close $fh;
print "\n🎉 CSV written to $output_csv\n";
