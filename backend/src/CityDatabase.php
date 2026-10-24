<?php
declare(strict_types=1);

namespace Minaret\Core;

/**
 * CityDatabase - Worldwide Gazetteer repository with primary focus on Pakistan & Global Islamic Cities
 */
class CityDatabase
{
    private static array $cities = [
        [
            'id' => 'farooka_pk',
            'name' => 'Farooka',
            'country' => 'Pakistan',
            'province' => 'Punjab',
            'latitude' => 31.8878,
            'longitude' => 72.4125,
            'timezone' => 5.0,
            'elevation' => 188
        ]
    ];

    /**
     * Search cities by keyword
     * @return array<int, array>
     */
    public static function search(string $query = ''): array
    {
        $q = trim(mb_strtolower($query));
        if ($q === '') {
            return self::$cities;
        }

        return array_values(array_filter(self::$cities, function ($city) use ($q) {
            return str_contains(mb_strtolower($city['name']), $q)
                || str_contains(mb_strtolower($city['country']), $q)
                || str_contains(mb_strtolower($city['province']), $q);
        }));
    }

    /**
     * Find city by ID
     */
    public static function findById(string $id): ?array
    {
        foreach (self::$cities as $city) {
            if ($city['id'] === $id) {
                return $city;
            }
        }
        return null;
    }
}
