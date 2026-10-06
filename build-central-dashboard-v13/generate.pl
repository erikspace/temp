#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use File::Path qw(make_path);
use Text::ParseWords qw(parse_line);
use POSIX qw(strftime);
use Time::Local qw(timelocal);

my $csv = $ARGV[0] // "$Bin/builds.csv";
my $out = $ARGV[1] // $Bin;

open my $fh, '<', $csv or die "Cannot open $csv: $!\n";
my $header = <$fh>;
die "CSV is empty\n" unless defined $header;
chomp $header;
$header =~ s/^\x{FEFF}//;
my @headers = parse_line(',', 1, $header);
my @rows;
while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    my @v = parse_line(',', 1, $line);
    my %r;
    @r{@headers} = map { defined $_ ? $_ : '' } @v;
    push @rows, \%r;
}
close $fh;

sub esc {
    my ($s) = @_;
    $s //= '';
    $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g;
    return $s;
}
sub attr { esc($_[0]) }
sub slug { my $s=lc($_[0]//''); $s =~ s/[^a-z0-9]+/-/g; $s =~ s/^-|-$//g; return $s; }
sub short_sha { my $s=$_[0]//'unknown'; return length($s)>8 ? substr($s,0,8) : $s; }
sub github_url { my $sha=$_[0]//' '; return "https://github.com/k-SpaceAssociates/main/commit/$sha"; }
sub parse_time {
    my ($s)=@_; return undef unless $s && $s =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)$/;
    return timelocal(0,$5,$4,$3,$2-1,$1);
}
sub fmt_time {
    my ($s) = @_;
    return '' unless $s;
    my $t = parse_time($s);
    return $s unless defined $t;
    return strftime('%I:%M %p', localtime($t)) =~ s/^0//r;
}
sub fmt_when {
    my ($s) = @_;
    return '' unless $s;
    my $t=parse_time($s); return $s unless defined $t;
    my $now=time();
    my $today=strftime('%Y-%m-%d',localtime($now));
    my $day=strftime('%Y-%m-%d',localtime($t));
    my $label = $day eq $today ? 'Today' : ($day eq strftime('%Y-%m-%d',localtime($now-86400)) ? 'Yesterday' : strftime('%b %-d',localtime($t)));
    return $label . ', ' . fmt_time($s);
}
sub ago {
    my ($s)=@_; my $t=parse_time($s); return 'Unknown' unless defined $t;
    my $d=time()-$t; $d=0 if $d<0;
    return 'just now' if $d<60;
    return int($d/60).' min ago' if $d<3600;
    return int($d/3600).' hr ago' if $d<86400;
    return int($d/86400).' days ago';
}
sub status_class { my $s=lc($_[0]//'unknown'); return $s eq 'passed' ? 'passed' : $s eq 'failed' ? 'failed' : $s eq 'running' ? 'running' : 'unknown'; }
sub status_symbol { my $s=lc($_[0]//''); return '✓' if $s eq 'passed'; return '!' if $s eq 'failed'; return '…' if $s eq 'running'; return '•'; }

# Newest first.
@rows = sort { (parse_time($b->{completed}) // 0) <=> (parse_time($a->{completed}) // 0) } @rows;
my %projects;
$projects{$_->{project}}++ for @rows;
my @projects = sort keys %projects;
my ($overnight) = grep { lc($_->{overnight}//'') =~ /^(1|yes|true)$/ } @rows;
$overnight //= $rows[0];
my $updated = @rows ? ago($rows[0]{completed}) : 'never';

my $project_nav = qq{<a href="#all" data-project="all" class="active">All Projects</a>\n};
for my $p (@projects) {
    $project_nav .= qq{      <a href="#} . slug($p) . qq{" data-project="} . attr($p) . qq{">} . esc($p) . qq{</a>\n};
}

my $build_html = '';
for my $r (@rows) {
    my $sc=status_class($r->{status});
    my $links = '';
    $links .= qq{<a href="} . attr($r->{logs} || 'buildlogs.html') . qq{">Logs</a>};
    $links .= qq{<a href="} . attr($r->{artifacts} || 'artifacts.html') . qq{">Artifacts</a>};
    $links .= qq{<a href="} . attr($r->{images} || 'buildimages.html') . qq{">Images</a>};
    my $sha=short_sha($r->{commit});
    $build_html .= qq{      <article class="build-row" data-project="} . attr($r->{project}) . qq{">\n};
    $build_html .= qq{        <div class="build-status $sc">} . status_symbol($r->{status}) . qq{</div>\n};
    $build_html .= qq{        <div class="build-main"><div class="build-title"><strong>} . esc($r->{project}) . qq{</strong><span>} . esc($r->{branch}) . qq{</span></div>\n};
    $build_html .= qq{          <div class="build-sub">#} . esc($r->{build}) . qq{ · <a class="commit-link" href="} . attr(github_url($r->{commit})) . qq{">} . esc($sha) . qq{</a> · } . esc($r->{description}) . qq{</div></div>\n};
    $build_html .= qq{        <div class="build-time"><span>} . esc(ucfirst(lc($r->{status}))) . qq{</span><strong>} . esc($r->{duration}) . qq{</strong></div>\n};
    $build_html .= qq{        <div class="build-when"><span>Completed</span><strong>} . esc(fmt_when($r->{completed})) . qq{</strong></div>\n};
    $build_html .= qq{        <div class="build-links">$links</div>\n      </article>\n\n};
}

my $hero_status=status_class($overnight->{status});
my $hero_sha=short_sha($overnight->{commit});
my $hero_start=fmt_time($overnight->{started});
my $hero_end=fmt_time($overnight->{completed});
my $hero_time=fmt_time($overnight->{completed});
my $hero_trigger=$overnight->{triggered_by} || 'Scheduled';
my $hero = qq{      <div class="eyebrow">OVERNIGHT BUILD</div>\n          <h2>} . esc($overnight->{project}) . qq{ · } . esc($overnight->{branch}) . qq{</h2>\n          <div class="build-meta"><span class="status $hero_status">● } . esc(ucfirst(lc($overnight->{status}))) . qq{</span><span>Build #} . esc($overnight->{build}) . qq{</span><span>commit <a class="commit-link" href="} . attr(github_url($overnight->{commit})) . qq{"><code>} . esc($hero_sha) . qq{</code></a></span></div>};

my $template = <<'HTML';
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Build Central</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">KSA</div>
      <div><strong>Build Central</strong><span>Engineering</span></div>
    </div>
    <nav>
      <a class="active" href="#" id="dashboard-link">Dashboard</a>
      <a href="buildhistory.html">Build History</a>
      <a href="artifacts.html">Artifacts</a>
      <a href="environments.html">Environments</a>
    </nav>
    <div class="section-label">Projects</div>
    <nav class="projects" aria-label="Projects">
%%PROJECT_NAV%%    </nav>
  </aside>
  <main>
    <header class="topbar">
      <div><h1>Build Dashboard</h1></div>
      <div class="top-actions"><span class="updated">Updated %%UPDATED%%</span><button onclick="location.reload()">Refresh</button></div>
    </header>
    <section class="hero">
      <div class="hero-heading">
        <div>
%%HERO%%
        </div>
        <div class="hero-result"><span>Completed</span><strong>%%HERO_TIME%%</strong><small>%%HERO_DURATION%% duration</small></div>
      </div>
      <div class="hero-details">
        <div><span>Started</span><strong>%%HERO_START%%</strong></div>
        <div><span>Completed</span><strong>%%HERO_END%%</strong></div>
        <div><span>Revision</span><strong>%%HERO_SHA%%</strong></div>
        <div><span>Triggered by</span><strong>%%HERO_TRIGGER%%</strong></div>
      </div>
    </section>
    <section class="section-header"><div><h2>Recent builds</h2><p>Latest activity across engineering projects</p></div></section>
    <section class="build-list">
%%BUILDS%%    </section>
    <section class="lower">
      <div class="panel">
        <div class="panel-header"><div><h2>Build system</h2><p>Current runner activity</p></div><span class="online">Operational</span></div>
        <div class="runner-row"><span class="runner-dot"></span><div><strong>Build runners</strong><span>All available</span></div><strong class="right">1 / 1</strong></div>
        <div class="runner-row"><span class="runner-dot"></span><div><strong>Artifact storage</strong><span>Available</span></div><strong class="right">Online</strong></div>
        <div class="runner-row"><span class="runner-dot"></span><div><strong>Mini DB</strong><span>Available</span></div><strong class="right">Online</strong></div>
      </div>
      <div class="panel">
        <div class="panel-header"><div><h2>Quick access</h2><p>Common build resources</p></div></div>
        <div class="quick-grid">
          <a href="buildlogs.html"><strong>Build logs</strong><span>Search and inspect logs →</span></a>
          <a href="artifacts.html"><strong>Artifacts</strong><span>Browse build outputs →</span></a>
          <a href="buildimages.html"><strong>Build images</strong><span>View generated images →</span></a>
          <a href="environments.html"><strong>Environments</strong><span>Deployment status →</span></a>
        </div>
      </div>
    </section>
  </main>
<script>
(() => {
  const projectLinks = [...document.querySelectorAll('.projects a[data-project]')];
  const buildRows = [...document.querySelectorAll('.build-row[data-project]')];
  const sectionTitle = document.querySelector('.section-header h2');
  const sectionSubtitle = document.querySelector('.section-header p');
  const dashboard = document.getElementById('dashboard-link');
  function setFilter(project) {
    const showAll = project === 'all';
    buildRows.forEach(row => { row.hidden = !showAll && row.dataset.project !== project; });
    projectLinks.forEach(link => link.classList.toggle('active', link.dataset.project === project));
    dashboard.classList.toggle('active', showAll);
    sectionTitle.textContent = showAll ? 'Recent builds' : `${project} builds`;
    sectionSubtitle.textContent = showAll ? 'Latest activity across engineering projects' : `Recent build activity for ${project}`;
  }
  projectLinks.forEach(link => link.addEventListener('click', event => { event.preventDefault(); setFilter(link.dataset.project); }));
  dashboard.addEventListener('click', event => { event.preventDefault(); setFilter('all'); });
})();
</script>
</body>
</html>
HTML

$template =~ s/%%PROJECT_NAV%%/$project_nav/e;
$template =~ s/%%UPDATED%%/esc($updated)/e;
$template =~ s/%%HERO%%/$hero/e;
$template =~ s/%%HERO_TIME%%/esc($hero_time)/e;
$template =~ s/%%HERO_DURATION%%/esc($overnight->{duration})/e;
$template =~ s/%%HERO_START%%/esc($hero_start)/e;
$template =~ s/%%HERO_END%%/esc($hero_end)/e;
$template =~ s/%%HERO_SHA%%/esc($hero_sha)/e;
$template =~ s/%%HERO_TRIGGER%%/esc($hero_trigger)/e;
$template =~ s/%%BUILDS%%/$build_html/e;

make_path($out) unless -d $out;
open my $outfh, '>', "$out/index.html" or die "Cannot write index.html: $!\n";
print $outfh $template;
close $outfh;

# Keep the simple resource pages present so Quick Access never points at missing files.
my @pages = (
  ['buildhistory.html','Build History','All recorded builds from builds.csv.'],
  ['buildlogs.html','Build Logs','Build log resources are provided by the build system.'],
  ['artifacts.html','Artifacts','Build artifacts are provided by the build system.'],
  ['buildimages.html','Build Images','Build images are provided by the build system.'],
  ['environments.html','Environments','Deployment and environment status.'],
);
for my $p (@pages) {
    open my $pf, '>', "$out/$p->[0]" or die "Cannot write $p->[0]: $!\n";
    print $pf qq{<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>} . esc($p->[1]) . qq{ · Build Central</title><link rel="stylesheet" href="styles.css"></head><body><main style="padding:40px;max-width:900px"><a href="index.html">← Build Dashboard</a><h1>} . esc($p->[1]) . qq{</h1><p>} . esc($p->[2]) . qq{</p></main></body></html>};
    close $pf;
}

print "Generated $out/index.html from $csv (" . scalar(@rows) . " builds)\n";
