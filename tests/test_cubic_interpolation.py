"""Independent numerical oracle and PAROLE's per-frame coverage contract."""
from pathlib import Path
import subprocess
import numpy as np
import pytest
from scipy.interpolate import PchipInterpolator

MODULE = Path(__file__).resolve().parents[1] / 'scripts' / 'interpolate_cubic.R'


def evaluate(tmp_path, x, y, target):
    np.savetxt(tmp_path / 'track.csv', np.column_stack([x, y]), delimiter=',', header='time,value', comments='')
    np.savetxt(tmp_path / 'target.csv', target, delimiter=',', header='time', comments='')
    script = '''args <- commandArgs(TRUE)
source(args[1])
d <- read.csv(args[2]); q <- read.csv(args[3])$time
write.table(interpolate_spline(d$time, d$value, q), args[4], row.names=FALSE, col.names=FALSE, na="NA")
'''
    runner = tmp_path / 'run.R'
    runner.write_text(script)
    subprocess.run(['Rscript', str(runner), str(MODULE), str(tmp_path/'track.csv'), str(tmp_path/'target.csv'), str(tmp_path/'out.csv')], check=True, capture_output=True, text=True)
    return np.atleast_1d(np.genfromtxt(tmp_path/'out.csv', missing_values='NA', filling_values=np.nan))


@pytest.mark.parametrize('y', [
    [0, 1, 1.5, 4, 4.2],       # monotone, irregular grid
    [4, 2, 2, -1, -2],         # descending with plateau
    [0, 3, -1, 2, 0],          # extrema (zero interior slopes)
    [2, 2, 2, 2, 2],           # constant
])
def test_matches_fritsch_butland_reference(tmp_path, y):
    x = np.array([0., .03, .09, .7, 1.2])
    q = np.linspace(-.02, 1.23, 301)
    actual = evaluate(tmp_path, x, y, q)
    np.testing.assert_allclose(actual, PchipInterpolator(x, y, extrapolate=True)(q), rtol=1e-11, atol=1e-11)


def test_cubic_not_linear_or_fmm(tmp_path):
    x = np.array([0., 1., 2., 3.]); y = np.array([0., 1., 1., 2.])
    q = np.array([.5, 1.5, 2.5])
    actual = evaluate(tmp_path, x, y, q)
    np.testing.assert_allclose(actual, [.6875, 1., 1.3125], atol=1e-12)
    assert not np.allclose(actual, np.interp(q, x, y))


def test_no_overshoot_inside_each_interval(tmp_path):
    x = np.array([0., .1, .4, .8, 1.]); y = np.array([0., 8., 2., 2., 5.])
    q = np.linspace(x[0], x[-1], 1001)
    actual = evaluate(tmp_path, x, y, q)
    indices = np.clip(np.searchsorted(x, q, side='right') - 1, 0, len(x)-2)
    assert np.all(actual >= np.minimum(y[indices], y[indices+1]) - 1e-12)
    assert np.all(actual <= np.maximum(y[indices], y[indices+1]) + 1e-12)


def test_every_frame_including_gaps_and_edges(tmp_path):
    x = [0.1, .2, 4., 4.1]; y = [100., 110., 140., 130.]
    q = np.array([0., .033, .1, .2, .333, 1.051, 2.137, 4., 4.1, 4.2])
    actual = evaluate(tmp_path, x, y, q)
    assert len(actual) == len(q) and np.isfinite(actual).all()
    np.testing.assert_allclose(actual, PchipInterpolator(x, y)(q), rtol=1e-11)
    np.testing.assert_allclose(evaluate(tmp_path, x, y, x), y)


def test_missing_values_and_duplicate_times(tmp_path):
    x = [2., 0., 1., 1., 3., 4.]; y = [2., 0., 1., 3., 4., np.nan]
    q = np.linspace(0, 3, 31)
    np.testing.assert_allclose(evaluate(tmp_path, x, y, q), PchipInterpolator([0,1,2,3], [0,2,2,4])(q))


def test_insufficient_track_remains_missing(tmp_path):
    assert np.isnan(evaluate(tmp_path, [0.,1.,2.], [1.,2.,3.], [0.,.5,1.])).all()
