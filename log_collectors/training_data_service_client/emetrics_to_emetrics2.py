#!/usr/bin/env python
"""transform emetrics 1 to emetrics2 string"""

#
# Copyright 2017-2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import json
from typing import Dict
from log_collectors.training_data_service_client import extract_datetime as edt


from log_collectors.training_data_service_client import training_data_pb2 as tdp


def get_test_emetrics_1_record()->tdp.EMetrics:
    return tdp.EMetrics(
        meta=tdp.MetaInfo(
            training_id="training-66b9JUVig",
            time=1527592527285,
            rindex=10,
            subid="learner-1"
        ),
        etimes={
            "iteration": tdp.Any(
                type=2,
                value="80"
            )
        },
        grouplabel="train",
        values={
            "learning-rate": tdp.Any(
                type=3,
                value="0.00994042"
            ),
            "loss": tdp.Any(
                type=3,
                value="0.0098897200077772148989223746382039384776"
            )
        }
    )


def make_eof_record(training_id: str, subid: str, rindex: int)->tdp.EMetrics:
    return tdp.EMetrics(
        meta=tdp.MetaInfo(
            training_id=training_id,
            time=edt.get_meta_timestamp(),
            rindex=rindex,
            subid=subid
        ),
        grouplabel="EOF",
        etimes={
            "iteration": tdp.Any(
                value="80"
            )
        },
        values={}
    )


def transform_typed_values_to_untyped(typed_dict: Dict)->Dict:
    untyped_dict = {}
    for k, v in typed_dict.items():
        type_of_val = v.type
        if type_of_val == tdp.Any.INT:
            untyped_dict[k] = int(v.value)
        elif type_of_val == tdp.Any.FLOAT:
            untyped_dict[k] = float(v.value)
        elif type_of_val == tdp.Any.STRING:
            untyped_dict[k] = str(v.value)
        elif type_of_val == tdp.Any.JSONSTRING:
            untyped_dict[k] = str(v.value)

    return untyped_dict


def transform(emetrics: tdp.EMetrics) -> str:
    untyped_etimes = transform_typed_values_to_untyped(emetrics.etimes)
    untyped_values = transform_typed_values_to_untyped(emetrics.values)

    emetrics_v2 = {
        "meta": {
            "training_id": emetrics.meta.training_id,
            "time": emetrics.meta.time,
            "rindex": emetrics.meta.rindex,
            "subid": emetrics.meta.subid
        },
        "entity": {
            "iteration": untyped_etimes["iteration"],
            "phase": emetrics.grouplabel,
            "machine_learning_metrics": untyped_values
        }
    }
    return json.dumps(emetrics_v2)
