// Particle Life - System Generation
//
// Generates random particle systems with species and forces

const std = @import("std");
const particle = @import("particle.zig");

/// Simple pseudo-random number generator for reproducible systems
/// Based on splitmix32 algorithm
pub const Rng = struct {
    state: u32,

    pub fn init(seed: u32) Rng {
        return .{ .state = seed };
    }

    pub fn next(self: *Rng) f32 {
        self.state +%= 0x9e3779b9;
        var t = self.state ^ (self.state >> 16);
        t = t *% 0x21f0aaad;
        t = t ^ (t >> 15);
        t = t *% 0x735a2d97;
        t = t ^ (t >> 15);
        return @as(f32, @floatFromInt(t)) / 4294967296.0;
    }

    pub fn range(self: *Rng, min: f32, max: f32) f32 {
        return min + self.next() * (max - min);
    }
};

/// Generate HSV color wheel for species
fn hsvToRgb(h: f32, s: f32, v: f32) [3]f32 {
    const c = v * s;
    const hh = h / 60.0;
    const x = c * (1.0 - @abs(@mod(hh, 2.0) - 1.0));
    const m = v - c;

    var rgb = [3]f32{ 0, 0, 0 };

    if (hh < 1.0) {
        rgb = [3]f32{ c, x, 0 };
    } else if (hh < 2.0) {
        rgb = [3]f32{ x, c, 0 };
    } else if (hh < 3.0) {
        rgb = [3]f32{ 0, c, x };
    } else if (hh < 4.0) {
        rgb = [3]f32{ 0, x, c };
    } else if (hh < 5.0) {
        rgb = [3]f32{ x, 0, c };
    } else {
        rgb = [3]f32{ c, 0, x };
    }

    return [3]f32{
        rgb[0] + m,
        rgb[1] + m,
        rgb[2] + m,
    };
}

/// Generate species colors distributed around color wheel
/// Matches reference implementation with gamma correction
pub fn generateSpeciesColors(species: []particle.Species, rng: *Rng) void {
    for (species) |*s| {
        // Random RGB with gamma correction (like reference)
        const r = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);
        const g = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);
        const b = std.math.pow(f32, 0.25 + rng.next() * 0.75, 2.2);

        s.* = particle.Species.init(r, g, b, 1.0);
    }
}

/// Generate random inter-species forces
/// Creates interesting emergent behaviors (matching reference implementation)
pub fn generateForceMatrix(forces: []particle.Force, species_count: u32, rng: *Rng, symmetric: bool) void {
    const n = species_count;
    const max_force_strength = 100.0;
    const max_force_radius = 32.0; // Match reference (smaller for tighter interactions)

    for (0..n) |i| {
        for (0..n) |j| {
            const idx = i * @as(usize, n) + j;

            // Random strength with 50% chance of attraction vs repulsion
            const strength_magnitude = max_force_strength * (0.25 + 0.75 * rng.next());
            const strength = if (rng.next() < 0.5) strength_magnitude else -strength_magnitude;

            // Collision strength proportional to force strength
            const collision_strength = (5.0 + 15.0 * rng.next()) * @abs(strength);

            // Random radius between 2.0 and max
            const radius = 2.0 + rng.next() * (max_force_radius - 2.0);

            // Collision radius is fraction of force radius
            const collision_radius = rng.next() * 0.5 * radius;

            forces[idx] = .{
                .strength = strength,
                .radius = radius,
                .collision_strength = collision_strength,
                .collision_radius = collision_radius,
            };
        }
    }

    if (symmetric) {
        for (0..n) |i| {
            for ((i + 1)..n) |j| {
                const idx_ij = i * @as(usize, n) + j;
                const idx_ji = j * @as(usize, n) + i;

                var f_ij = forces[idx_ij];
                var f_ji = forces[idx_ji];

                const strength = (f_ij.strength + f_ji.strength) / 2.0;
                const radius = (f_ij.radius + f_ji.radius) / 2.0;
                const collision_strength = (f_ij.collision_strength + f_ji.collision_strength) / 2.0;
                const collision_radius = (f_ij.collision_radius + f_ji.collision_radius) / 2.0;

                f_ij.strength = strength;
                f_ji.strength = strength;
                f_ij.radius = radius;
                f_ji.radius = radius;
                f_ij.collision_strength = collision_strength;
                f_ji.collision_strength = collision_strength;
                f_ij.collision_radius = collision_radius;
                f_ji.collision_radius = collision_radius;

                forces[idx_ij] = f_ij;
                forces[idx_ji] = f_ji;
            }
        }
    }
}

